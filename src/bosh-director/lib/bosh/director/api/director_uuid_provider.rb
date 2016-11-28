module Bosh
  module Director
    module Api
      class DirectorUUIDProvider
        def initialize(config)
          @config = config
        end

        def uuid
          @config.uuid
        end
      end
    end
  end
end
