module Bosh
  module Director
    module DeploymentPlan
      module PlacementPlanner
        class Plan
          def initialize(desired, existing, networks, availability_zones)
            @networks = networks
            @desired = desired
            @existing = existing
            @availability_zones = availability_zones
          end

          def needed
            results[:desired_new]
          end

          def existing
            results[:desired_existing]
          end

          def obsolete
            results[:obsolete]
          end

          private

          def results
            @results ||= begin
              if has_static_ips?
                StaticIpsAvailabilityZonePicker.new.place_and_match_in(@availability_zones, @networks, @desired, @existing)
              else
                AvailabilityZonePicker.new.place_and_match_in(@availability_zones, @desired, @existing)
              end
            end

            # assign indexes to @results
          end

          def has_static_ips?
            !@networks.nil? && @networks.any? { |network| !! network.static_ips }
          end
        end
      end
    end
  end
end
