require_relative 'ami'
require_relative 'light_stemcell'

module Bosh
  module Helpers
    class CandidateArtifacts
      def initialize(stemcell_tgz)
        @stemcell_tgz = stemcell_tgz
      end

      def publish
        ami = Bosh::Helpers::Ami.new(stemcell_tgz)
        light_stemcell = LightStemcell.new(ami)
        light_stemcell.publish(ami.publish)
      end

      private
      attr_reader :stemcell_tgz
    end
  end
end
