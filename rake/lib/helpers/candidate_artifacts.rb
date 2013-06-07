require_relative 'pipeline'
require_relative 'stemcell'

module Bosh
  module Helpers
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
