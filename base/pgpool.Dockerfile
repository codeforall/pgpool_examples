FROM pgsql-pgpool:10
MAINTAINER m.usama@gmail.com
ARG MYHOSTNAME
ARG WD_NODE0_HOST
ARG WD_NODE1_HOST


ENV PGPORT=5432
ENV PGPOOLPORT=9999
ENV PCPPORT=9898

COPY scripts/wait_for_pg_server.sh /tmp/wait_for_pg_server.sh

RUN mkdir /certs
RUN cp ${CERTDIR}/server.key /certs/server.key
RUN cp ${CERTDIR}/server.crt /certs/server.crt
RUN cp ${CERTDIR}/root.crt /certs/root.crt

#use security through obfuscation technique for network commands
RUN su postgres -c "mkdir /home/postgres/network_utils"
RUN cp sbin/ip /home/postgres/network_utils/
RUN cp /usr/sbin/arping /home/postgres/network_utils/
RUN chmod u+s /home/postgres/network_utils/ip
RUN chmod u+s /home/postgres/network_utils/arping

# Set up pgpool config files
RUN sed -i "s/^port = .*/port = ${PGPOOLPORT}/"         ${PGPOOLCONF}/pgpool.conf
RUN sed -i "s/^pid_file_name = .*/pid_file_name = '\/var\/run\/pgpool\/pgpool.pid'/"  ${PGPOOLCONF}/pgpool.conf
RUN sed -i "s/^listen_addresses = 'localhost'/listen_addresses = '*'/"  ${PGPOOLCONF}/pgpool.conf
RUN sed -i "s/^ssl = .*/ssl = on/"  ${PGPOOLCONF}/pgpool.conf
RUN sed -i "s/^#ssl_key = .*/ssl_key = '\/certs\/server.key'/"  ${PGPOOLCONF}/pgpool.conf
RUN sed -i "s/^#ssl_cert = .*/ssl_cert = '\/certs\/server.crt'/"  ${PGPOOLCONF}/pgpool.conf
RUN sed -i "s/^#ssl_ca_cert = .*/ssl_ca_cert = '\/certs\/root.crt'/"  ${PGPOOLCONF}/pgpool.conf
RUN sed -i "s/^enable_pool_hba = .*/enable_pool_hba = on/"  ${PGPOOLCONF}/pgpool.conf
RUN sed -i "s/^master_slave_mode = .*/master_slave_mode = on/"  ${PGPOOLCONF}/pgpool.conf
RUN sed -i "s/^load_balance_mode = .*/load_balance_mode = on/"  ${PGPOOLCONF}/pgpool.conf

SHELL ["/bin/bash", "-c"]
RUN echo -en  "\
sr_check_user = 'postgres'\n\
health_check_user = 'postgres'\n\
health_check_period = 5\n\
recovery_user = 'postgres'\n\
recovery_1st_stage_command = 'recovery_1st_stage'\n\
if_cmd_path = '/home/postgres/network_utils'\n\
arping_path = '/home/postgres/network_utils'\n\
if_up_cmd = 'ip addr add \$_IP_$/24 dev eth0 label eth0:0'\n\
if_down_cmd = 'ip addr del \$_IP_$/24 dev eth0'\n\
arping_cmd = 'arping -U \$_IP_$ -w 1 -I eth0'\n\
follow_master_command = '${PGPOOLCONF}/follow_master.sh %d %h %p %D %m %M %H %P %r %R'\n\
failover_command = '${PGPOOLCONF}/failover.sh %d %h %p %D %m %H %M %P %r %R %N %S'\n" \
>> ${PGPOOLCONF}/pgpool.conf
SHELL ["/bin/sh", "-c"]


RUN echo "postgres:e8a48653851e28c69d0506508fb27fc5" >> ${PGPOOLCONF}/pcp.conf


COPY scripts/failover.sh ${PGPOOLCONF}/failover.sh
COPY scripts/follow_master.sh ${PGPOOLCONF}/follow_master.sh

RUN chown postgres:postgres ${PGPOOLCONF}/failover.sh
RUN chown postgres:postgres ${PGPOOLCONF}/follow_master.sh

RUN chmod +x ${PGPOOLCONF}/failover.sh
RUN chmod +x ${PGPOOLCONF}/follow_master.sh

RUN sed -i "s/^PGMAJOR=.*/PGMAJOR=$PGMAJOR/" ${PGPOOLCONF}/failover.sh
RUN sed -i "s/^PGMAJOR=.*/PGMAJOR=$PGMAJOR/" ${PGPOOLCONF}/follow_master.sh

RUN touch ${PGPOOLCONF}/pool_passwd
RUN chown postgres:postgres ${PGPOOLCONF}/pool_passwd

#setup pool_hba.conf

RUN echo "local     all         all                           trust" > ${PGPOOLCONF}/pool_hba.conf
RUN echo "host      all         postgres           0.0.0.0/0  trust" >> ${PGPOOLCONF}/pool_hba.conf
RUN echo "hostssl   all         postgres           0.0.0.0/0  trust" >> ${PGPOOLCONF}/pool_hba.conf
#RUN echo "hostnossl all         all                0.0.0.0/0  scram-sha-256" >> ${PGPOOLCONF}/pool_hba.conf
#RUN echo "hostssl   all         all                0.0.0.0/0  cert" >> ${PGPOOLCONF}/pool_hba.conf

#create the key file
RUN sudo -u postgres echo "pool_pass_key" > /home/postgres/.pgpoolkey
RUN chmod 0600 /home/postgres/.pgpoolkey
RUN chown postgres:postgres /home/postgres/.pgpoolkey
#create pcp pass file for passwordless pcp access
RUN sudo -u postgres echo "*:*:*:postgres" > /home/postgres/.pcppass
RUN  chmod 0600 /home/postgres/.pcppass
RUN chown postgres:postgres /home/postgres/.pcppass

RUN sudo -u postgres pg_enc -u certuser -m cert_password
RUN sudo -u postgres pg_enc -u scramuser -m scram_password
RUN sudo -u postgres pg_enc -u postgres -m postgres



#CMD /tmp/wait_for_pg_server.sh  &&service sshd start && tail -F ${PGPOOLLOG}

EXPOSE ${PGPOOLPORT}
EXPOSE ${PCPPORT}
CMD echo "exiting"

