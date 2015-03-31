# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module Api
  end
end

require 'bosh/director/api/http_constants'

require 'bosh/director/api/api_helper'
require 'bosh/director/api/task_helper'

require 'bosh/director/api/backup_manager'
require 'bosh/director/api/deployment_manager'
require 'bosh/director/api/instance_manager'
require 'bosh/director/api/problem_manager'
require 'bosh/director/api/property_manager'
require 'bosh/director/api/release_manager'
require 'bosh/director/api/resource_manager'
require 'bosh/director/api/snapshot_manager'
require 'bosh/director/api/stemcell_manager'
require 'bosh/director/api/compiled_package_group_manager'
require 'bosh/director/api/task_manager'
require 'bosh/director/api/user_manager'
require 'bosh/director/api/vm_state_manager'
require 'bosh/director/api/backup_manager'
require 'bosh/director/api/resurrector_manager'
require 'bosh/director/api/cloud_config_manager'

require 'bosh/director/api/instance_lookup'
require 'bosh/director/api/deployment_lookup'
