require 'bosh/director/core/templates'

module Bosh::Director::Core::Templates
  RenderedFileTemplate = Struct.new(:src_name, :dest_name, :contents)
end
