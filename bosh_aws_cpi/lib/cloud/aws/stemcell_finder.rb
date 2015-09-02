require 'cloud/aws/light_stemcell'
require 'cloud/aws/stemcell'

module Bosh::AwsCloud
  class StemcellFinder
    def self.find_by_region_and_id(region, id)
      if id =~ / light$/
        LightStemcell.new(Stemcell.find(region, id[0...-6]), Bosh::Clouds::Config.logger)
      else
        Stemcell.find(region, id)
      end
    end
  end
end
