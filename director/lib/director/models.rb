require "director/models/compiled_package"
require "director/models/deployment"
require "director/models/deployment_problem"
require "director/models/deployment_property"
require "director/models/instance"
require "director/models/log_bundle"
require "director/models/package"
require "director/models/release"
require "director/models/release_version"
require "director/models/stemcell"
require "director/models/task"
require "director/models/template"
require "director/models/user"
require "director/models/vm"
require "director/models/persistent_disk"

module Bosh::Director
  module Models
    VALID_ID = /^[-a-z0-9_.]+$/i
  end
end

