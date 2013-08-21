require 'net/http'

module Bosh
  module Stemcell
    class AwsRegistry
      def region
        Net::HTTP.get('169.254.169.254', '/latest/meta-data/placement/availability-zone').chop
      end
    end
  end
end
