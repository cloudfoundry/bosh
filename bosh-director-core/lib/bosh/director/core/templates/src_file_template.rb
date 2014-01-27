require 'bosh/director/core/templates'

module Bosh::Director::Core::Templates
  SrcFileTemplate = Struct.new(:src_name, :dest_name, :erb_file)
end
