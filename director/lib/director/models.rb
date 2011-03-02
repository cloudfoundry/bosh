require "director/models/compiled_package"
require "director/models/deployment"
require "director/models/instance"
require "director/models/package"
require "director/models/release"
require "director/models/release_version"
require "director/models/stemcell"
require "director/models/template"
require "director/models/task"
require "director/models/user"
require "director/models/vm"

module Bosh::Director
  module Models
    VALID_ID = /^[-a-z0-9_.]+$/i
  end
end
