#!/bin/bash -x
MASTER_IP=
SLAVE_IP=
ROLE=
MASTER_PORT=5432
ARCHIVEDIR=/var/lib/pgsql/archivedir
echo setting up server in $ROLE role.

if test -z $ROLE ; then 
    echo "server role not provided"
fi

if [ $ROLE = "standby" ]; then
	RECOVERYCONF=${PGDATA}/recovery.conf
	SLOT_NAME=$(echo $SLAVE_IP | sed "s:\.:_:g")
    # wait for master server to get online
    until psql -h ${MASTER_IP} -U "postgres" -c '\q'; do
          >&2 echo "Postgres is unavailable - sleeping"
            sleep 1
    done
    echo "mastar Postgres is up - executing basebackup command"
	# create a replication slot
	psql -h ${MASTER_IP} -U "postgres" << EOQ
SELECT pg_create_physical_replication_slot('${SLOT_NAME}');
EOQ

    #delete the old data forlder first
    rm -rf ${PGDATA}
    sudo -u postgres pg_basebackup -RP -p 5432 -h ${MASTER_IP} -D ${PGDATA} -X stream

	cat > ${RECOVERYCONF} << EOT
primary_conninfo = 'host=${MASTER_IP} port=${MASTER_PORT} user=postgres application_name=${SLAVE_IP} passfile=''/var/lib/pgsql/.pgpass'''
recovery_target_timeline = 'latest'
restore_command = 'scp ${MASTER_IP}:${ARCHIVEDIR}/%f %p'
primary_slot_name = '${SLOT_NAME}'
EOT
	echo standby_mode = 'on' >> ${RECOVERYCONF}
fi
