# pgpool_2PG_node_setup
This repository showcase the example of configuring Pgpool-II with two PostgreSQL backends.

# Overview
The example creates four containers "pgmaster", "pgstandby",pgpoolNode and "clientnode".
"pgmaster" and "pgstandby" hosts the PostgreSQL instance master and standby respectively, While "pgpoolNode" runs the Pgpool-II.

This example can be used to test the backend failover, online recovery and different PCP commands of Pgpool-II
All these above mentioned images are created using "pgsql-pgpool" docker image (also created by this example),
which is just a centos:6.6 docker image with PostgreSQL and Pgpool-II installed.

# How to build and run

To run the example do the following:
```
docker-compose build
docker-compose up
```
