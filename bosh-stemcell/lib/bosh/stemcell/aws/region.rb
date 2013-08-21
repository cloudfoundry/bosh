require 'net/http'

module Bosh
  module Stemcell
    module Aws
      class Region
        def name
          Net::HTTP.get('169.254.169.254', '/latest/meta-data/placement/availability-zone').chop
        end
      end
    end
  end
end
