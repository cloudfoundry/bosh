require 'net/http'

module Bosh
  module Stemcell
    module Aws
      class Region
        DEFAULT = 'us-east-1'
        REGIONS = %w{
          us-east-1 us-west-1 us-west-2 eu-west-1 eu-central-1
          ap-southeast-1 ap-southeast-2 ap-northeast-1 ap-northeast-2
          sa-east-1
        }
      end
    end
  end
end
