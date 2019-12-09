#!/bin/bash -x
IP=pgmaster
PORT=5432
#the script always try to connect with postgres user
echo checking for postgresql server at $IP:$PORT.

if test -z $IP ; then 
    echo "server IP not provided"
fi
if test -z $PORT ; then 
    echo "server port not provided"
fi

psql template1 -h ${IP} -p ${PORT} -U "postgres" -c 'CREATE EXTENSION pgpool_recovery'
echo "pgpool_recovery installed in Postgres at $IP:$PORT"
