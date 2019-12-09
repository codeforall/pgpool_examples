#!/bin/bash -x
IP=
PORT=5432
#the script always try to connect with postgres user
echo checking for postgresql server at $IP:$PORT.

if test -z $IP ; then 
    echo "server IP not provided"
fi
if test -z $PORT ; then 
    echo "server port not provided"
fi

until psql -h ${IP} -p ${PORT} -U "postgres" -c '\q'; do
    >&2 echo "Postgres is unavailable - sleeping"
    sleep 1
done
echo "Postgres at $IP:$PORT is up and running"
