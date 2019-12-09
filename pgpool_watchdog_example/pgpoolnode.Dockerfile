FROM pgpool:41
MAINTAINER m.usama@gmail.com
ARG MYHOSTNAME
ARG WD_NODE0_HOST
ARG WD_NODE1_HOST
ARG WD_PRIORITY

SHELL ["/bin/bash", "-c"]
RUN sed -i "s/^IP=.*/IP=pgstandby/" ${SCRIPTS}/wait_for_pg_server.sh
RUN sed -i "s/^PORT=.*/PORT=5432/" ${SCRIPTS}/wait_for_pg_server.sh
#watchdog setup
# Set up pgpool config files
RUN echo -en " \n\
backend_hostname0 = 'pgmaster' \n\
backend_port0 = ${PGPORT} \n\
backend_data_directory0 = '/var/lib/pgsql/$PGMAJOR/data' \n\
backend_hostname1 = 'pgstandby' \n\
backend_port1 = ${PGPORT} \n\
backend_data_directory1 = '/var/lib/pgsql/$PGMAJOR/data' \n\
use_watchdog = on \n\
delegate_IP = '172.22.0.100' \n\
wd_hostname = '${MYHOSTNAME}' \n\

other_pgpool_hostname0 = '${WD_NODE0_HOST}' \n\
heartbeat_destination0 = '${WD_NODE0_HOST}'\n\
other_pgpool_port0 = 9999 \n\
other_wd_port0 = 9000 \n\
other_pgpool_hostname1 = '${WD_NODE1_HOST}' \n\
heartbeat_destination1 = '${WD_NODE1_HOST}' \n\
other_pgpool_port1 = 9999 \n\
other_wd_port1 = 9000 \n\
wd_priority = ${WD_PRIORITY}" >> ${PGPOOLCONF}/pgpool.conf
CMD ${SCRIPTS}/wait_for_pg_server.sh && service sshd start && service rsyslog start && service ${PGPOOLSERVICE_NAME} start && tail -F ${PGPOOLLOG}
#CMD /tmp/wait_for_pg_server.sh && /tmp/install_extensions.sh &&service sshd start && tail -F ${PGPOOLLOG}

EXPOSE ${PGPOOLPORT}
EXPOSE ${PCPPORT}

