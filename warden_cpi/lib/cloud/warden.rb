require "uuidtools"

require "cloud"
require "cloud/warden/helpers"
require "cloud/warden/cloud"
require "cloud/warden/version"

require "warden/client"

puts 'reqed'

module Bosh
  module Clouds
    Warden = Bosh::WardenCloud::Cloud
  end
end
