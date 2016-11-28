require 'bosh/dev/build'
require 'bosh/stemcell/archive'

module Bosh::Dev
  class StemcellPublisher
    def self.for_candidate_build(bucket_name)
      new(Build.candidate bucket_name)
    end

    def initialize(build)
      @build = build
    end

    def publish(stemcell_filename)
      stemcell = Bosh::Stemcell::Archive.new(stemcell_filename)
      @build.upload_stemcell(stemcell)
    end
  end
end
