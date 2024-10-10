require 'bosh/director/core/templates'

module Bosh::Director::Core::Templates
  RenderedFileTemplate = Struct.new(:src_filepath, :dest_filepath, :contents)
end
