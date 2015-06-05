#!/bin/bash

export PATH=/usr/lib/postgresql/9.4/bin:$PATH
export PGDATA=/tmp/postgres
export PGLOGS=/tmp/log/postgres
mkdir -p $PGDATA
mkdir -p $PGLOGS
