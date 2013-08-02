require 'bosh/stemcell/stemcell'
require 'bosh/stemcell/aws/light_stemcell'

module Bosh::Stemcell
  module LightStemcellCreator
    def self.create(stemcell)
      light_stemcell = Aws::LightStemcell.new(stemcell)
      light_stemcell.write_archive
      Stemcell.new(light_stemcell.path)
    end
  end
end
