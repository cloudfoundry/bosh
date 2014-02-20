module Bosh
end

require 'logger'
require 'time'
require 'yaml'
require 'set'

require 'nats/client'
require 'yajl'
require 'securerandom'
require 'ostruct'
require 'fileutils'
require 'resolv'
require 'ipaddr'
require 'httpclient'
require 'sigar'

require 'common/exec'
require 'common/properties'
require 'bosh/core/encryption_handler'

module Bosh::Agent
  BOSH_APP = BOSH_APP_USER = BOSH_APP_GROUP = 'vcap'
end

require 'bosh_agent/ext'
require 'bosh_agent/version'

require 'bosh_agent/template'
require 'bosh_agent/errors'
require 'bosh_agent/remote_exception'

require 'bosh_agent/sigar_box'
require 'bosh_agent/config'
require 'bosh_agent/util'
require 'bosh_agent/monit'

require 'bosh_agent/infrastructure'
require 'bosh_agent/platform'

require 'bosh_agent/platform/linux'
require 'bosh_agent/platform/linux/adapter'
require 'bosh_agent/platform/linux/disk'
require 'bosh_agent/platform/linux/logrotate'
require 'bosh_agent/platform/linux/password'
require 'bosh_agent/platform/linux/network'

require 'bosh_agent/platform/ubuntu'
require 'bosh_agent/platform/ubuntu/network'

require 'bosh_agent/platform/centos'
require 'bosh_agent/platform/centos/disk'
require 'bosh_agent/platform/centos/network'

require 'bosh_agent/bootstrap'

require 'bosh_agent/alert'
require 'bosh_agent/alert_processor'
require 'bosh_agent/smtp_server'
require 'bosh_agent/heartbeat'
require 'bosh_agent/heartbeat_processor'
require 'bosh_agent/state'
require 'bosh_agent/settings'
require 'bosh_agent/file_matcher'
require 'bosh_agent/file_aggregator'
require 'bosh_agent/ntp'
require 'bosh_agent/syslog_monitor'

require 'bosh_agent/apply_plan/helpers'
require 'bosh_agent/apply_plan/job'
require 'bosh_agent/apply_plan/package'
require 'bosh_agent/apply_plan/plan'

require 'bosh_agent/disk_util'

require 'bosh_agent/message/base'

require 'bosh_agent/message/list_disk'
require 'bosh_agent/message/migrate_disk'
require 'bosh_agent/message/mount_disk'
require 'bosh_agent/message/unmount_disk'

require 'bosh_agent/message/state'
require 'bosh_agent/message/drain'
require 'bosh_agent/message/apply'
require 'bosh_agent/message/compile_package'
require 'bosh_agent/message/logs'
require 'bosh_agent/message/ssh'
require 'bosh_agent/message/run_errand'

require 'bosh_agent/handler'
require 'bosh_agent/runner'
