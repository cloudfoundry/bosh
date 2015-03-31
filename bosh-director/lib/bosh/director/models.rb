# Copyright (c) 2009-2012 VMware, Inc.
#

require 'bosh/director/models/cloud_config'
require 'bosh/director/models/compiled_package'
require 'bosh/director/models/deployment'
require 'bosh/director/models/deployment_problem'
require 'bosh/director/models/deployment_property'
require 'bosh/director/models/director_attribute'
require 'bosh/director/models/instance'
require 'bosh/director/models/log_bundle'
require 'bosh/director/models/package'
require 'bosh/director/models/release'
require 'bosh/director/models/release_version'
require 'bosh/director/models/stemcell'
require 'bosh/director/models/snapshot'
require 'bosh/director/models/task'
require 'bosh/director/models/template'
require 'bosh/director/models/user'
require 'bosh/director/models/vm'
require 'bosh/director/models/persistent_disk'
require 'bosh/director/models/rendered_templates_archive'

module Bosh::Director
  module Models
    VALID_ID = /^[-0-9A-Za-z_+.]+$/i

    autoload :Dns, 'bosh/director/models/dns'
  end
end

