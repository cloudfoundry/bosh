maintainer       "VMware"
maintainer_email "ac-eng@vmware.com"
license          "All rights reserved"
description      "Installs/Configures ntp"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.rdoc'))
version          "0.0.1"

recipe "ntp", "Configures ntp synchronization hourly from cron"
