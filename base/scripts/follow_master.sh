#!/bin/bash
# This script is run after failover_command to synchronize the Standby with the new Primary.
# First try pg_rewind. If pg_rewind failed, use pg_basebackup.

set -o xtrace
exec > >(logger -i -p local1.info) 2>&1
#follow_master.sh %d %h %p %D %m %M %H %P %r %R'
# Special values:
#   %d = failed node id
#   %h = failed node hostname
#   %p = failed node port number
#   %D = failed node database cluster path
#   %m = new master node id
#   %H = new master node hostname
#   %M = old master node id
#   %P = old primary node id
#   %r = new master port number
#   %R = new master database cluster path
#   %N = old primary node hostname
#   %S = old primary node port number
#   %% = '%' character

FAILED_NODE_ID="$1"                # %d
FAILED_NODE_HOST="$2"              # %h
FAILED_NODE_PORT="$3"              # %p
FAILED_NODE_PGDATA="$4"            # %D
NEW_MASTER_NODE_ID="$5"            # %m
OLD_MASTER_NODE_ID="$6"            # %M
NEW_MASTER_NODE_HOST="$7"          # %H
OLD_PRIMARY_NODE_ID="$8"           # %P
NEW_MASTER_NODE_PORT="$9"          # %r
NEW_MASTER_NODE_PGDATA="${10}"     # %R

ARCHIVEDIR=/var/lib/pgsql/archivedir
REPLUSER=postgres
PCP_USER=postgres
PGPOOL_PATH=/usr/bin
PCP_PORT=9898

PGMAJOR=11
PGHOME=/usr/pgsql-${PGMAJOR}

FAILED_NODE_HOST_SLOT_NAME=$(echo $FAILED_NODE_HOST | sed "s:\.:_:g")

logger -i -p local1.info follow_master.sh: start: Standby node ${FAILED_NODE_ID}

## Test passwrodless SSH
ssh -T -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null postgres@${NEW_MASTER_NODE_HOST} -i ~/.ssh/id_rsa_pgpool ls /tmp > /dev/null

if [ $? -ne 0 ]; then
    logger -i -p local1.info follow_master.sh: passwrodless SSH to postgres@${NEW_MASTER_NODE_HOST} failed. Please setup passwrodless SSH.
    exit 1
fi

## Get PostgreSQL major version
PGVERSION=`${PGHOME}/bin/initdb -V | awk '{print $3}' | sed 's/\..*//' | sed 's/\([0-9]*\)[a-zA-Z].*/\1/'`

if [ $PGVERSION -ge 12 ]; then
RECOVERYCONF=${FAILED_NODE_PGDATA}/myrecovery.conf
else
RECOVERYCONF=${FAILED_NODE_PGDATA}/recovery.conf
fi

## Check the status of Standby
ssh -T -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
postgres@${FAILED_NODE_HOST} -i ~/.ssh/id_rsa_pgpool ${PGHOME}/bin/pg_ctl -w -D ${FAILED_NODE_PGDATA} status


## If Standby is running, synchronize it with the new Primary.
if [ $? -eq 0 ]; then

    logger -i -p local1.info follow_master.sh: pg_rewind for $FAILED_NODE_ID

    # Create replication slot "${FAILED_NODE_HOST}"
    ssh -T -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null postgres@${NEW_MASTER_NODE_HOST} -i ~/.ssh/id_rsa_pgpool "
        ${PGHOME}/bin/psql -p ${NEW_MASTER_NODE_PORT} -c \"SELECT pg_create_physical_replication_slot('${FAILED_NODE_HOST_SLOT_NAME}');\"
    "

    ssh -T -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null postgres@${FAILED_NODE_HOST} -i ~/.ssh/id_rsa_pgpool "

        set -o errexit

        ${PGHOME}/bin/pg_ctl -w -m f -D ${FAILED_NODE_PGDATA} stop

        cat > ${RECOVERYCONF} << EOT
primary_conninfo = 'host=${NEW_MASTER_NODE_HOST} port=${NEW_MASTER_NODE_PORT} user=${REPLUSER} application_name=${FAILED_NODE_HOST} passfile=''/var/lib/pgsql/.pgpass'''
recovery_target_timeline = 'latest'
restore_command = 'scp ${NEW_MASTER_NODE_HOST}:${ARCHIVEDIR}/%f %p'
primary_slot_name = '${FAILED_NODE_HOST_SLOT_NAME}'
EOT

        if [ ${PGVERSION} -ge 12 ]; then
            touch ${FAILED_NODE_PGDATA}/standby.signal
        else
            echo \"standby_mode = 'on'\" >> ${RECOVERYCONF}
        fi

        ${PGHOME}/bin/pg_rewind -D ${FAILED_NODE_PGDATA} --source-server=\"user=postgres host=${NEW_MASTER_NODE_HOST} port=${NEW_MASTER_NODE_PORT}\"

    "

    if [ $? -ne 0 ]; then
        logger -i -p local1.error follow_master.sh: end: pg_rewind failed. Try pg_basebackup.

        ssh -T -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null postgres@${FAILED_NODE_HOST} -i ~/.ssh/id_rsa_pgpool "
             
            set -o errexit

            # Execute pg_basebackup
            rm -rf ${FAILED_NODE_PGDATA}
            rm -rf ${ARCHIVEDIR}/*
            ${PGHOME}/bin/pg_basebackup -h ${NEW_MASTER_NODE_HOST} -U $REPLUSER -p ${NEW_MASTER_NODE_PORT} -D ${FAILED_NODE_PGDATA} -X stream

            if [ ${PGVERSION} -ge 12 ]; then
                sed -i -e \"\\\$ainclude_if_exists = '$(echo ${RECOVERYCONF} | sed -e 's/\//\\\//g')'\" \
                       -e \"/^include_if_exists = '$(echo ${RECOVERYCONF} | sed -e 's/\//\\\//g')'/d\" ${FAILED_NODE_PGDATA}/postgresql.conf
            fi
     
            cat > ${RECOVERYCONF} << EOT
primary_conninfo = 'host=${NEW_MASTER_NODE_HOST} port=${NEW_MASTER_NODE_PORT} user=${REPLUSER} application_name=${FAILED_NODE_HOST} passfile=''/var/lib/pgsql/.pgpass'''
recovery_target_timeline = 'latest'
restore_command = 'scp ${NEW_MASTER_NODE_HOST}:${ARCHIVEDIR}/%f %p'
primary_slot_name = '${FAILED_NODE_HOST_SLOT_NAME}'
EOT

            if [ ${PGVERSION} -ge 12 ]; then
                    touch ${FAILED_NODE_PGDATA}/standby.signal
            else
                    echo \"standby_mode = 'on'\" >> ${RECOVERYCONF}
            fi
        "

        if [ $? -ne 0 ]; then
            # drop replication slot
            ssh -T -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null postgres@${NEW_MASTER_NODE_HOST} -i ~/.ssh/id_rsa_pgpool "
                ${PGHOME}/bin/psql -p ${NEW_MASTER_NODE_PORT} -c \"SELECT pg_drop_replication_slot('${FAILED_NODE_HOST_SLOT_NAME}')\"
            "

            logger -i -p local1.error follow_master.sh: end: pg_basebackup failed
            exit 1
        fi
    fi

    # start Standby node on ${FAILED_NODE_HOST}
    ssh -T -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
            postgres@${FAILED_NODE_HOST} -i ~/.ssh/id_rsa_pgpool $PGHOME/bin/pg_ctl -l /dev/null -w -D ${FAILED_NODE_PGDATA} start

    # If start Standby successfully, attach this node
    if [ $? -eq 0 ]; then

        # Run pcp_attact_node to attach Standby node to Pgpool-II.
        ${PGPOOL_PATH}/pcp_attach_node -w -h localhost -U $PCP_USER -p ${PCP_PORT} -n ${FAILED_NODE_ID}

        if [ $? -ne 0 ]; then
                logger -i -p local1.error follow_master.sh: end: pcp_attach_node failed
                exit 1
        fi

    # If start Standby failed, drop replication slot "${FAILED_NODE_HOST}"
    else

        ssh -T -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null postgres@${NEW_MASTER_NODE_HOST} -i ~/.ssh/id_rsa_pgpool \
        ${PGHOME}/bin/psql -p ${NEW_MASTER_NODE_PORT} -c "SELECT pg_drop_replication_slot('${FAILED_NODE_HOST_SLOT_NAME}')"

        logger -i -p local1.error follow_master.sh: end: follow master command failed
        exit 1
    fi

else
    logger -i -p local1.info follow_master.sh: failed_nod_id=${FAILED_NODE_ID} is not running. skipping follow master command
    exit 0
fi

logger -i -p local1.info follow_master.sh: end: follow master command complete
exit 0
