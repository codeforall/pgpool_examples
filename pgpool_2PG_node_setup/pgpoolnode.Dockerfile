FROM pgpool:41
MAINTAINER m.usama@gmail.com

SHELL ["/bin/bash", "-c"]
RUN sed -i "s/^IP=.*/IP=pgstandby/" ${SCRIPTS}/wait_for_pg_server.sh
RUN sed -i "s/^PORT=.*/PORT=5432/" ${SCRIPTS}/wait_for_pg_server.sh
# Set up pgpool config files
RUN echo -en " \n\
backend_hostname0 = 'pgmaster' \n\
backend_port0 = ${PGPORT} \n\
backend_data_directory0 = '/var/lib/pgsql/$PGMAJOR/data' \n\
backend_hostname1 = 'pgstandby' \n\
backend_port1 = ${PGPORT} \n\
backend_data_directory1 = '/var/lib/pgsql/$PGMAJOR/data'" >> ${PGPOOLCONF}/pgpool.conf
CMD ${SCRIPTS}/wait_for_pg_server.sh && service sshd start && service rsyslog start && service ${PGPOOLSERVICE_NAME} start && tail -F ${PGPOOLLOG}

EXPOSE ${PGPOOLPORT}
EXPOSE ${PCPPORT}

