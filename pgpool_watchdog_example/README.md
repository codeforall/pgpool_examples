# pgpool_watchdog_example
This repository showcase the example of using Pgpool-II with watchdog

# Overview
The example creates six containers "pgmaster", "pgstandby", "pgpoolNode0",pgpoolNode1, pgpoolNode2 and "clientnode".
"pgmaster" and "pgstandby" hosts the PostgreSQL instance master and standby respectively, While "pgpoolNode[n]" runs the three node Pgpool-II cluster.

All these above mentioned images are created using "pgsql-pgpool" docker image (also created by this example),
which is just a centos:6.6 docker image with PostgreSQL and Pgpool-II installed.

# How to build and run

To run the exmaple do the following:
```
docker-compose build
docker-compose up
```
