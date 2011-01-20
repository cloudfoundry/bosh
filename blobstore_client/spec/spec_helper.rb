require 'rspec/core'

$:.unshift(File.expand_path("../../lib", __FILE__))
require 'blobstore_client'

RSpec.configure do |c|
  c.color_enabled = true
end
