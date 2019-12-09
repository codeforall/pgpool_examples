FROM pgsql-pgpool:10
MAINTAINER m.usama@gmail.com

ARG ROLE
ARG MASTER_IP
ARG SLAVE_IP

ENV PGPORT=5432
ENV ROLE_=$ROLE

RUN sed -i "s/^MASTER_IP=/MASTER_IP=pgmaster/" ${SCRIPTS}/setup_pg_server.sh
RUN sed -i "s/^SLAVE_IP=/SLAVE_IP=pgstandby/" ${SCRIPTS}/setup_pg_server.sh
RUN sed -i "s/^ROLE=/ROLE=$ROLE/" ${SCRIPTS}/setup_pg_server.sh

#copy the server certificates data directory
RUN cp ${CERTDIR}/server.key ${PGDATA}/server.key
RUN cp ${CERTDIR}/server.crt ${PGDATA}/server.crt
RUN cp ${CERTDIR}/root.crt ${PGDATA}/root.crt

RUN chmod 0600 ${PGDATA}/server.key && chown postgres:postgres ${PGDATA}/server.key
RUN chmod 0600 ${PGDATA}/server.crt && chown postgres:postgres ${PGDATA}/server.crt
RUN chmod 0600 ${PGDATA}/root.crt && chown postgres:postgres ${PGDATA}/root.crt

SHELL ["/bin/bash", "-c"]
RUN echo -en "wal_level = replica \n\
wal_log_hints = on \n\
max_wal_senders = 8 \n\
wal_keep_segments = 100 \n\
max_replication_slots = 6 \n\
hot_standby = on \n\
ssl = on \n\
ssl_cert_file = 'server.crt' \n\
ssl_key_file = 'server.key' \n\
ssl_ca_file = 'root.crt' \n\
listen_addresses = '*'"    >> ${PGDATA}/postgresql.conf


RUN echo "local  all         all                 trust" >  ${PGDATA}/pg_hba.conf
RUN echo "local  replication all                 trust" >> ${PGDATA}/pg_hba.conf
RUN echo "host   replication all           0.0.0.0/0  trust" >> ${PGDATA}/pg_hba.conf
RUN echo "host   all         all      0.0.0.0/0  trust" >> ${PGDATA}/pg_hba.conf
RUN echo "host   all         all      0.0.0.0/0   trust" >> ${PGDATA}/pg_hba.conf

RUN echo "export ROLE=${ROLE}"         >> /etc/profile.d/pg_env.sh
CMD ${SCRIPTS}/setup_pg_server.sh && service ${PGSERVICE_NAME}  start && service sshd start && service rsyslog start && tail -F ${PGLOG}

EXPOSE ${PGPORT}
