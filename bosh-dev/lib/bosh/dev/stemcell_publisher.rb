require 'bosh/dev/build'
require 'bosh/stemcell/archive'
require 'bosh/stemcell/aws/light_stemcell'

module Bosh::Dev
  class StemcellPublisher
    def self.for_candidate_build
      new(Build.candidate)
    end

    def initialize(build)
      @build = build
    end

    def publish(stemcell_filename)
      stemcell = Bosh::Stemcell::Archive.new(stemcell_filename)
      publish_light_stemcell(stemcell) if stemcell.infrastructure == 'aws'
      @build.upload_stemcell(stemcell)
    end

    private

    def publish_light_stemcell(stemcell)
      %w{ paravirtual hvm }.each { |virtualization_type|
        light_stemcell = Bosh::Stemcell::Aws::LightStemcell.new(stemcell, virtualization_type)
        light_stemcell.write_archive

        light_stemcell_stemcell = Bosh::Stemcell::Archive.new(light_stemcell.path)
        @build.upload_stemcell(light_stemcell_stemcell)
      }
    end
  end
end
