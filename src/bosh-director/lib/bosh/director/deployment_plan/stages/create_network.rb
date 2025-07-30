module Bosh::Director
  module DeploymentPlan
    module Stages
      class CreateNetworkStage
        include LockHelper
        include IpUtil

        def initialize(logger, deployment_plan)
          @logger = logger
          @deployment_plan = deployment_plan
        end

        def perform
          create_networks
        end

        private

        def create_networks
          return unless Config.network_lifecycle_enabled?

          @logger.info('Network lifecycle check')
          @event_log_stage = Config.event_log.begin_stage('Creating managed networks')

          @deployment_plan.instance_groups.each do |inst_group|
            inst_group.networks.each do |jobnetwork|
              network = jobnetwork.deployment_network

              next unless network.managed?

              with_network_lock(network.name) do
                db_network = Bosh::Director::Models::Network.first(name: network.name)
                db_network = create_network(network) if db_network.nil?

                if db_network.orphaned
                  db_network.orphaned = false
                  db_network.save
                end

                # add relation between deployment and network
                @deployment_plan.model.add_network(db_network) unless @deployment_plan.model.networks.include?(db_network)

                # fetch the subnet cloud properties from the database
                network.subnets.each do |subnet|
                  db_subnet = db_network.subnets.find { |sn| sn.name == subnet.name }
                  raise Bosh::Director::SubnetNotFoundInDB, "cannot find subnet: #{subnet.name} in the database" if db_subnet.nil?
                  populate_subnet_properties(subnet, db_subnet)
                end
              end
            end
          end
        end

        def create_network(network)
          validate_subnets(network)

          @logger.info("Creating network: #{network.name}")

          created_network = nil

          @event_log_stage.advance_and_track(network.name.to_s) do
            created_network = Bosh::Director::Models::Network.create(
              name: network.name,
              type: 'manual',
              orphaned: false,
              created_at: Time.now,
            )

            begin
              rollback = {}

              network.subnets.each do |subnet|
                create_subnet(subnet, created_network, rollback)
              end
            rescue StandardError => e
              rollback.each do |cid, cpi|
                begin
                  @logger.info("deleting subnet #{cid}")
                  cpi.delete_network(cid)
                rescue StandardError => e
                  @logger.info("failed to delete subnet #{cid}: #{e.message}")
                end
              end

              @logger.info("deleting network #{created_network.name}")
              created_network.destroy

              raise "deployment failed during creating managed networks: #{e.message}"
            end
          end

          created_network
        end

        def validate_subnets(network)
          names = {}
          network.subnets.each do |subnet|
            raise 'subnet in managed network must have a name' if subnet.name.nil?
            raise 'subnet names within a managed network must be unique' if names.key?(subnet.name)
            names[subnet.name] = true
          end
        end

        def create_subnet(subnet, network_model, rollback)
          cloud_factory = AZCloudFactory.create_with_latest_configs(@deployment_plan.model)
          cpi_name = ''
          az_cloud_properties = {}

          if !subnet.availability_zone_names.nil? && subnet.availability_zone_names.count != 0
            cpi_name = cloud_factory.get_name_for_az(subnet.availability_zone_names.first)
            subnet.availability_zone_names.each do |az_name|
              availability_zone = @deployment_plan.availability_zones.find { |az| az.name == az_name }
              az_cloud_properties.merge!(availability_zone.cloud_properties)
            end
          end

          cpi = cloud_factory.get(cpi_name)
          network_create_results = cpi.create_network(fetch_cpi_input(subnet, az_cloud_properties))
          network_cid = network_create_results[0]
          network_address_properties = network_create_results[1]
          network_cloud_properties = network_create_results[2]

          range = subnet.range ? subnet.range.to_s : network_address_properties['range']
          gw = subnet.gateway ? subnet.gateway : network_address_properties['gateway']

          reserved_ips = network_address_properties.fetch('reserved', [])
          rollback[network_cid] = cpi
          sn = Bosh::Director::Models::Subnet.new(
            cid: network_cid,
            cloud_properties: JSON.dump(network_cloud_properties),
            name: subnet.name,
            range: range,
            gateway: gw,
            reserved: JSON.dump(reserved_ips),
            cpi: cpi_name,
          )
          network_model.add_subnet(sn)
          sn.save
        end

        def fetch_cpi_input(subnet, az_cloud_props)
          az_cloud_props ||= {}
          cpi_input = {
            'type' => 'manual',
            'cloud_properties' => {},
          }
          cpi_input['cloud_properties'] = az_cloud_props.merge(subnet.cloud_properties) if subnet.cloud_properties
          cpi_input['range'] = subnet.range.to_s if subnet.range
          cpi_input['gateway'] = subnet.gateway.base_addr if subnet.gateway
          cpi_input['netmask_bits'] = subnet.netmask_bits if subnet.netmask_bits
          cpi_input
        end

        def populate_subnet_properties(subnet, db_subnet)
          subnet.cloud_properties = JSON.parse(db_subnet.cloud_properties)
          subnet.range = Bosh::Director::IpAddrOrCidr.new(db_subnet.range)
          subnet.gateway = Bosh::Director::IpAddrOrCidr.new(db_subnet.gateway)
          subnet.netmask = subnet.range.netmask

          subnet.restricted_ips.add(subnet.gateway) if subnet.gateway
          subnet.restricted_ips.add(subnet.range)
          subnet.restricted_ips.add(subnet.range.to_range.last)
          each_ip(JSON.parse(db_subnet.reserved)) do |ip|
            unless subnet.range.include?(ip)
              raise NetworkReservedIpOutOfRange,
                    "Reserved IP '#{to_ipaddr(ip)}' is out of subnet '#{subnet.name}' range"
            end
            subnet.restricted_ips.add(ip)
          end
        end
      end
    end
  end
end
