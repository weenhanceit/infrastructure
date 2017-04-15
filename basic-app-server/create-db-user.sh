#!/bin/bash

psql -U root \
  -d ${DATABASE:?"Please set DATABASE=database"} \
  -h weit-rds-a.cwfow80ezu1x.ca-central-1.rds.amazonaws.com <<EOF
create role ${DATABASE_USERNAME:?"Please set DATABASE_USERNAME=username"}
  with createdb
  login password '${DATABASE_PASSWORD:?"Please set DATABASE_PASSWORD=password"}';
grant rds_superuser to $DATABASE_USERNAME;
EOF
