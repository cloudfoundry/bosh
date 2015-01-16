Syslog aggregator (from cf-release) depends on
newer rsyslog (7.4.6) with relp which is not
part of the default rsyslog (5.8.10) in Ubuntu
or CentOS.

Default rsyslog is not simply uninstalled because
cronie CentOS package depends on it. Instead
/sbin/rsyslogd is symlinked to compiled version
of rsyslog (in /usr/local/sbin/rsyslogd).

For now rsyslog is compiled during stemcell building
but hopefully in the future releases that depend on
rsyslog can bosh package it themselves.
