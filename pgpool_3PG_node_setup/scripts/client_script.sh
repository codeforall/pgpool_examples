#!/bin/bash -x
PGPOOL_IP=172.22.0.52
PGPOOL_PORT=9999

until psql -h ${PGPOOL_IP} -p ${PGPOOL_PORT} -U "postgres" -c '\q'; do
    >&2 echo "Pgpool is unavailable - sleeping"
    sleep 1
done
echo "Pgpool-II is up and running"
sleep 5
# create users
psql -h ${PGPOOL_IP} -p ${PGPOOL_PORT} -U postgres -c "SET password_encryption = 'scram-sha-256'; CREATE ROLE scramuser PASSWORD 'scram_password'; ALTER ROLE scramuser WITH LOGIN;" postgres
psql -h ${PGPOOL_IP} -p ${PGPOOL_PORT} -U postgres -c "SET password_encryption = 'scram-sha-256'; CREATE ROLE certuser PASSWORD 'cert_password'; ALTER ROLE certuser WITH LOGIN;" postgres

echo "testing if ssl connection without proper client certificate is rejected"
sudo -u postgres psql "sslmode=require port=9999 host=172.22.0.52 dbname=postgres user=scramuser"

echo "testing if ssl connection with proper client certificate works"
sudo -u postgres psql "sslmode=require port=9999 host=172.22.0.52 dbname=postgres user=certuser"
tail -f /dev/null

