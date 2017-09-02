!#/usr/bin/env ruby


require 'aws-sdk'
require 'aws-sdk-core'
rds = Aws::RDS::Client.new
rds.reboot_db_instance(:db_instance_identifier => ENV['RDS_MYSQL_DB_IDENTIFIER'])