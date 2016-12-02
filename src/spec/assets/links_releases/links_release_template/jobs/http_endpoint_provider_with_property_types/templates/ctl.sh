#!/bin/bash

JOB_NAME=http_server_with_provides
RUN_DIR=/var/vcap/sys/run/$JOB_NAME
LOG_DIR=/var/vcap/sys/log/$JOB_NAME
PIDFILE=$RUN_DIR/pid

mkdir -p $RUN_DIR $LOG_DIR
chown -R vcap:vcap $RUN_DIR $LOG_DIR

exec 1>> $LOG_DIR/$JOB_NAME.stdout.log
exec 2>> $LOG_DIR/$JOB_NAME.stderr.log

source /var/vcap/packages/http_server/pid_utils.sh

case $1 in

  start)
    pid_guard $PIDFILE $JOB_NAME

    echo $$ > $PIDFILE

    exec chpst -u vcap:vcap /var/vcap/packages/http_server/bin/httpd --port <%= p("listen_port") %>

    ;;

  stop)
    kill_and_wait $PIDFILE

    ;;

  *)
    echo "Usage: $0 {start|stop}"

    ;;

esac
