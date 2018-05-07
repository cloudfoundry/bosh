module Bosh
  module Director
    module Api
      class AvailabilityZoneManager
        def initialize
          @az_hash = Models::LocalDnsEncodedAz.as_hash(:name, :id)
        end

        def is_az_valid?(az_name)
          @az_hash.has_key?(az_name)
        end
      end
    end
  end
end