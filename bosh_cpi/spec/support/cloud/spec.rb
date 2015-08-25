#used by unit/provider_spec.rb to test Provider.create
module Bosh
  module Clouds
    class Spec
      attr_reader :settings

      def initialize(options) ; end

      def create_vm(settings)
        @settings = settings
        @settings['key'] = 'modified'
      end
    end
  end
end
