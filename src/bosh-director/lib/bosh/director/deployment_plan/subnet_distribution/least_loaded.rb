module Bosh
  module Director
    module DeploymentPlan
      module SubnetDistribution
        # Least-loaded strategy: order candidate subnets so new VMs spread evenly
        # across the subnets of an AZ.
        #
        # Subnets are tried least-loaded first (by count of dynamic IPs already
        # allocated in that subnet), with manifest order as a stable tiebreak.
        # Existing instances reuse their DB-backed reservation and never reach this
        # path, so their IPs count as load and scale-up naturally fills the emptier
        # subnet.
        #
        # nic_group co-location: networks that share a nic_group land on one NIC/ENI,
        # and IaaS (e.g. AWS) requires every address on one ENI to come from the same
        # subnet. So when a same-nic_group sibling has already been assigned an IP for
        # this instance, this reservation is pinned to that sibling's subnet (matched
        # by cloud_properties) instead of being balanced independently — otherwise the
        # per-network least-loaded sort could scatter the siblings across different
        # subnets. Whichever sibling reserves first is the "leader" and balances freely;
        # the rest follow it. Order-independent. If a leader is placed but this network has
        # no candidate subnet matching its cloud_properties, that is a topology misconfig
        # (sibling networks not mirroring subnets) and #order fails loud rather than scatter.
        class LeastLoaded
          # @networks is the name-keyed Hash built in CloudPlanner; used to resolve a
          # sibling row's network back to its ManualNetwork for co-location.
          def initialize(networks)
            @networks = networks
            # Per-network dynamic-IP counts { network_name => { subnet => count } }, seeded lazily
            # from the DB on the first balancing decision for a network (see #counts_for) and then
            # kept current via #record_allocation / #record_release. This turns per-reservation
            # balancing from an O(all dynamic rows) rescan into an O(1) lookup for the rest of the
            # deploy. A strategy instance lives exactly one deployment's IP-reservation pass
            # (IpProvider is memoized per CloudPlanner), so the cache is scoped to one deploy.
            @counts_by_network = {}
          end

          def order(candidates, reservation)
            leader_props = nic_group_leader_cloud_properties(reservation)
            if leader_props
              pinned = candidates.select { |subnet| subnet.cloud_properties == leader_props }
              return pinned unless pinned.empty?

              # A same-nic_group sibling is already placed, but no candidate subnet of this
              # network matches its cloud_properties. Balancing this reservation independently
              # would scatter the ENI's addresses across different IaaS subnets, which the IaaS
              # rejects at create_vm time (AWS: all addresses on one ENI must share a subnet).
              # Fail loud here with an actionable message rather than letting it surface later
              # as an opaque CPI error. See the nic_group co-location note above.
              raise Bosh::Director::NetworkReservationError,
                    "Cannot co-locate nic_group '#{reservation.nic_group}' network " \
                    "'#{reservation.network.name}' for instance '#{reservation.instance_model}': a " \
                    "sibling NIC is already placed on a subnet with cloud_properties " \
                    "#{leader_props.inspect}, but no subnet of this network in the instance's AZ " \
                    'has matching cloud_properties. Networks sharing a nic_group must mirror subnet ' \
                    'cloud_properties so every address on one ENI comes from the same IaaS subnet.'
            end

            # No co-location constraint. A lone candidate needs no balancing (and no load
            # query); with two or more, order least-loaded first with manifest order as tiebreak.
            return candidates if candidates.size == 1

            counts = counts_for(reservation.network)
            candidates.each_with_index
                      .sort_by { |subnet, idx| [counts.fetch(subnet, 0), idx] }
                      .map(&:first)
          end

          # Notified by IpProvider after it allocates a dynamic IP in `subnet` on `network`, so the
          # cached counts track this deploy's own allocations without a rescan. Only mutates an
          # already-seeded network; an unseeded one is left alone and reseeds fresh from the DB on
          # its next balancing decision (self-correcting, never half-maintained).
          def record_allocation(network, subnet)
            counts = @counts_by_network[network.name]
            counts[subnet] += 1 if counts&.key?(subnet)
          end

          # Symmetric to #record_allocation: notified by IpProvider after it releases a dynamic IP.
          def record_release(network, subnet)
            counts = @counts_by_network[network.name]
            return unless counts&.key?(subnet)

            counts[subnet] -= 1 if counts[subnet].positive?
          end

          private

          # cloud_properties of the subnet a same-nic_group sibling was already assigned
          # to for this instance, or nil if there is no sibling yet (this reservation is
          # the leader), the reservation has no nic_group, or the sibling network cannot
          # be resolved. @networks is the name-keyed Hash built in CloudPlanner; some
          # specs pass a non-Hash collection, in which case co-location is simply skipped.
          #
          # Both static and dynamic siblings count: whatever is already placed on the ENI
          # fixes its subnet, so a dynamic reservation must follow a static sibling too
          # (e.g. static IPv4 + dynamic IPv6 on one nic_group, or a static->dynamic
          # migration in progress). Filtering to dynamic-only here would let the follower
          # scatter onto a different subnet than a static leader.
          def nic_group_leader_cloud_properties(reservation)
            return nil unless reservation.nic_group
            return nil unless reservation.instance_model
            return nil unless @networks.is_a?(Hash)

            sibling = Models::IpAddress
                      .where(instance_id: reservation.instance_model.id,
                             nic_group: reservation.nic_group)
                      .exclude(network_name: reservation.network.name)
                      .first
            return nil unless sibling

            sibling_network = @networks[sibling.network_name]
            return nil unless sibling_network

            subnet = sibling_network.find_subnet_containing(sibling.address)
            subnet&.cloud_properties
          end

          # Cached { subnet => dynamic-IP count } for the whole network, seeded once from the DB.
          # Seeding is lazy (first balancing decision for the network) so the snapshot already
          # includes every dynamic IP committed by then — existing instances, provided IPs that
          # resolved to dynamic, re-reserved IPs. From then on #record_allocation/#record_release
          # keep it current for this deploy's own changes.
          #
          # Tradeoffs (acceptable because least_loaded is a balancing heuristic, never a capacity
          # gate — free-IP/capacity is enforced by IpRepo#allocate_dynamic_ip): a dynamic IP added
          # after seeding via a non-notified path, or by a concurrent deploy on a shared
          # cloud-config network, is not reflected until the next fresh deploy. Worst case is
          # slightly imperfect balancing, never an incorrect placement.
          def counts_for(network)
            @counts_by_network[network.name] ||= scan_counts(network)
          end

          # One full scan of the network's dynamic IPs, bucketed across ALL its subnets (not just
          # one AZ's candidates) so a single seed serves every AZ. counts is keyed by subnet object
          # identity, which is safe only because both these subnets and the ones #order sorts (and
          # the ones IpProvider passes to #record_*) are the same ManualNetworkSubnet instances held
          # on `network`, never reconstructed copies. If a future change rebuilds subnet objects,
          # counts would silently miss and bias the balance.
          def scan_counts(network)
            counts = network.subnets.to_h { |subnet| [subnet, 0] }
            Models::IpAddress.where(network_name: network.name, static: false).each do |addr|
              subnet = network.find_subnet_containing(addr.address)
              counts[subnet] += 1 if counts.key?(subnet)
            end
            counts
          end
        end
      end
    end
  end
end
