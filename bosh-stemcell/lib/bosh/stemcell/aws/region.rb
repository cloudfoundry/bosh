require 'net/http'

module Bosh
  module Stemcell
    module Aws
      class Region
        DEFAULT = 'us-east-1'

        def name
          Net::HTTP.get('169.254.169.254', '/latest/meta-data/placement/availability-zone').chop
        end
      end
    end
  end
end
