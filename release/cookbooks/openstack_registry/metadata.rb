version          "0.0.1"
maintainer       "VMware"
maintainer_email "support@vmware.com"
license          "TBD"
description      "Installs/configures BOSH OpenStack Registry"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.rdoc'))

depends "env"
depends "ruby"
depends "rubygems"
depends "runit"