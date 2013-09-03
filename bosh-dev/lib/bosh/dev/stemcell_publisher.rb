require 'bosh/dev/build'
require 'bosh/stemcell/archive'
require 'bosh/stemcell/aws/light_stemcell'

module Bosh::Dev
  class StemcellPublisher
    def publish(stemcell_filename)
      stemcell = Bosh::Stemcell::Archive.new(stemcell_filename)

      publish_light_stemcell(stemcell) if stemcell.infrastructure == 'aws'

      Build.candidate.upload_stemcell(stemcell)
    end

    private

    def publish_light_stemcell(stemcell)
      light_stemcell = Bosh::Stemcell::Aws::LightStemcell.new(stemcell)
      light_stemcell.write_archive
      light_stemcell_stemcell = Bosh::Stemcell::Archive.new(light_stemcell.path)

      Build.candidate.upload_stemcell(light_stemcell_stemcell)
    end
  end
end
