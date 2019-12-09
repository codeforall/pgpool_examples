FROM centos:6.6
MAINTAINER m.usama@gmail.com

ARG CERTUSERNAME

ENV PGMAJOR=11
ENV PGPOOLVER=4.1
ENV PGSERVICE_NAME=postgresql-${PGMAJOR}
ENV PGPOOLSERVICE_NAME=pgpool
ENV PATH=/usr/pgsql-${PGMAJOR}/bin:${PATH}
ENV PGDATA=/var/lib/pgsql/${PGMAJOR}/data
ENV PGPOOLCONF=/etc/pgpool-II/
ENV PGLOG=/var/lib/pgsql/${PGMAJOR}/pgstartup.log
ENV PGPOOLLOG=/var/log/pgpool.log
ENV CERTDIR=/certificates
ENV SCRIPTS=/scripts

RUN adduser --home-dir /home/postgres --create-home postgres

RUN rpm -Uvh https://yum.postgresql.org/${PGMAJOR}/redhat/rhel-6-x86_64/pgdg-redhat${PGMAJOR}-${PGMAJOR}-2.noarch.rpm
RUN yum install -y yum-plugin-ovl
RUN yum install -y sudo
RUN yum install -y postgresql${PGMAJOR}-server postgresql${PGMAJOR}
RUN yum install -y vim
RUN yum install -y openssh
RUN yum install -y openssh-server
RUN yum install -y openssh-clients
RUN yum install -y rsyslog
RUN yum install -y http://www.pgpool.net/yum/rpms/${PGPOOLVER}/redhat/rhel-6-x86_64/pgpool-II-pg${PGMAJOR}-${PGPOOLVER}.0-2pgdg.rhel6.x86_64.rpm
RUN yum install -y http://www.pgpool.net/yum/rpms/${PGPOOLVER}/redhat/rhel-6-x86_64/pgpool-II-pg${PGMAJOR}-extensions-${PGPOOLVER}.0-2pgdg.rhel6.x86_64.rpm
RUN echo 'root:root'|chpasswd

# setting postgres user for login
RUN echo 'postgres   ALL=(ALL)   NOPASSWD: ALL' >> /etc/sudoers
RUN echo 'postgres:postgres'|chpasswd

#copy scripts for generating certificates
RUN mkdir ${CERTDIR}
COPY ./scripts/generate_client_ssl_crt.sh ${CERTDIR}/generate_client_ssl_crt.sh
COPY ./scripts/generate_server_ssl_crt.sh ${CERTDIR}/generate_server_ssl_crt.sh

RUN mkdir ${SCRIPTS}
COPY ./scripts/setup_pg_server.sh ${SCRIPTS}/setup_pg_server.sh
RUN chmod +x ${SCRIPTS}/setup_pg_server.sh
COPY ./scripts/wait_for_pg_server.sh ${SCRIPTS}/wait_for_pg_server.sh
RUN chmod +x ${SCRIPTS}/wait_for_pg_server.sh

#create certificates
RUN if [ "x$CERTUSERNAME" = "x" ] ; then cd ${CERTDIR} && ./generate_server_ssl_crt.sh certuser; else cd ${CERTDIR} && ./generate_server_ssl_crt.sh ${CERTUSERNAME}; fi
RUN if [ "x$CERTUSERNAME" = "x" ] ; then cd ${CERTDIR} && ./generate_client_ssl_crt.sh certuser; else cd ${CERTDIR} && ./generate_client_ssl_crt.sh ${CERTUSERNAME}; fi

#initialize database
RUN service ${PGSERVICE_NAME} initdb
RUN touch ${PGPOOLCONF}/pool_passwd

#set up the password less ssh connection between hosts
RUN mkdir -p ~/.ssh && chmod 700 ~/.ssh
RUN su - postgres -c "mkdir -p /home/postgres/.ssh && chmod 700 /home/postgres/.ssh"
RUN su - postgres -c "cat /dev/zero | ssh-keygen -t rsa -b 4096 -C 'm.usama@gmail.com' -q -N '' -f /home/postgres/.ssh/id_rsa_pgpool"
RUN su - postgres -c "cat /home/postgres/.ssh/id_rsa_pgpool.pub >> /home/postgres/.ssh/authorized_keys"
RUN su - postgres -c "chmod 600 /home/postgres/.ssh/authorized_keys"
RUN cat /home/postgres/.ssh/id_rsa_pgpool.pub >> ~/.ssh/authorized_keys
RUN chmod 600 ~/.ssh/authorized_keys

RUN su postgres -c "ssh-keyscan -H 172.22.0.50 >> ~/.ssh/known_hosts"
RUN su postgres -c "ssh-keyscan -H 172.22.0.51 >> ~/.ssh/known_hosts"
RUN su postgres -c "ssh-keyscan -H 172.22.0.52 >> ~/.ssh/known_hosts"
RUN su postgres -c "ssh-keyscan -H 172.22.0.53 >> ~/.ssh/known_hosts"
RUN su postgres -c "ssh-keyscan -H 172.22.0.54 >> ~/.ssh/known_hosts"
RUN su postgres -c "ssh-keyscan -H 172.22.0.55 >> ~/.ssh/known_hosts"

#set the pgpool config files
RUN echo "export PATH=${PATH}"                              >> /etc/profile.d/pg_env.sh
RUN echo "export PGSERVICE_NAME=${PGSERVICE_NAME}"          >> /etc/profile.d/pg_env.sh
RUN echo "export PGPOOLSERVICE_NAME=${PGPOOLSERVICE_NAME}"  >> /etc/profile.d/pg_env.sh
RUN echo "export PGDATA=${PGDATA}"                          >> /etc/profile.d/pg_env.sh
RUN echo "export PGPOOLCONF=${PGPOOLCONF}"                  >> /etc/profile.d/pg_env.sh
RUN echo "export CERTDIR=${CERTDIR}"                        >> /etc/profile.d/pg_env.sh

COPY ./scripts/pgpool_remote_start ${PGDATA}/
COPY ./scripts/recovery_1st_stage ${PGDATA}/
RUN chown postgres:postgres ${PGDATA}/pgpool_remote_start
RUN chown postgres:postgres ${PGDATA}/recovery_1st_stage
RUN chmod +x ${PGDATA}/pgpool_remote_start
RUN chmod +x ${PGDATA}/recovery_1st_stage

RUN sed -i "s/^PGMAJOR=.*/PGMAJOR=$PGMAJOR/" ${PGDATA}/pgpool_remote_start
RUN sed -i "s/^PGMAJOR=.*/PGMAJOR=$PGMAJOR/" ${PGDATA}/recovery_1st_stage
#auto start sshd on startup
RUN chkconfig --add sshd
#RUN chkconfig sshd on
CMD echo "exiting"
