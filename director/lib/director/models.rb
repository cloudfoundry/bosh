Sequel::Model.plugin :validation_helpers

Sequel::Model.raise_on_typecast_failure = false

[:exact_length, :format, :includes, :integer, :length_range, :max_length,
 :min_length, :not_string, :numeric, :type, :presence, :unique].each do |validation|
  Sequel::Plugins::ValidationHelpers::DEFAULT_OPTIONS[validation][:message] = validation
end
Sequel::Plugins::ValidationHelpers::DEFAULT_OPTIONS[:max_length][:nil_message] = :max_length

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
