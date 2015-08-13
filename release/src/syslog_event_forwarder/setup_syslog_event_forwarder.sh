#!/usr/bin/env sh

# Taken from metron's syslog configuration at
# https://github.com/cloudfoundry/loggregator/blob/master/src/metron/syslog_daemon_config/setup_syslog_forwarder.sh

if [ $# -ne 1 ]
then
    echo "Usage: setup_syslog_event_forwarder.sh [Config dir]"
    exit 1
fi

CONFIG_DIR=$1

# Place to spool logs if the upstream server is down
mkdir -p /var/vcap/sys/rsyslog/buffered
chown -R syslog:adm /var/vcap/sys/rsyslog/buffered
CURRENT_IP=$(ifconfig eth0 | grep -Eo 'inet (addr:)?([0-9]+\.){3}[0-9]+' | grep -Eo '([0-9]+\.){3}[0-9]+')
# did not find a reliable way to find out microbosh IP using erb template, so we replace __CURRENT_IP__ here
sed "s/__CURRENT_IP__/$CURRENT_IP/g" $CONFIG_DIR/syslog_event_forwarder.conf > /etc/rsyslog.d/00-syslog_event_forwarder.conf

service rsyslog restart