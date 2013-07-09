require 'bosh/dev/pipeline'
require 'bosh/dev/stemcell'

module Bosh
  module Dev
    class CandidateArtifacts
      def initialize(stemcell_tgz)
        @pipeline = Pipeline.new
        @stemcell = Stemcell.new(stemcell_tgz)
      end

      def publish
        pipeline.publish_stemcell(stemcell.create_light_stemcell)
      end

      private
      attr_reader :pipeline, :stemcell
    end
  end
end
