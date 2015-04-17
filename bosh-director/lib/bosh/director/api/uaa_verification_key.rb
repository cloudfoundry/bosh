module Bosh
  module Director
    module Api
      class UAAVerificationKey
        def initialize(verification_key, info)
          @verification_key = verification_key
          @info = info
        end

        def value
          @value ||= fetch
        end

        def refresh
          @value = nil
        end

        private

        def fetch
          @verification_key || @info.validation_key['value']
        end
      end
    end
  end
end
