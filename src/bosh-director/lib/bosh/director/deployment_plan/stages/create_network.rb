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

        def fetch_cpi_input(subnet, az_cloud_props)
          az_cloud_props ||= {}
          cpi_input = {
            'type': 'manual',
            'cloud_properties': {},
          }
          cpi_input['cloud_properties'] = az_cloud_props.merge(subnet.cloud_properties) if subnet.cloud_properties
          cpi_input['range'] = subnet.range.to_s if subnet.range
          cpi_input['gateway'] = subnet.gateway.ip if subnet.gateway
          cpi_input['netmask_bits'] = subnet.netmask_bits if subnet.netmask_bits
          cpi_input
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
          range = if subnet.range
                    subnet.range.to_s
                  else
                    network_address_properties['range']
                  end
          gw = if subnet.gateway
                 subnet.gateway.ip
               else
                 network_address_properties['gateway']
               end
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

        def create_network_if_not_exists(network)
          return if Bosh::Director::Models::Network.first(name: network.name)
          validate_subnets(network)
          @logger.info("Creating network: #{network.name}")
          @event_log_stage.advance_and_track(network.name.to_s) do
            # update the network database tables
            nw = Bosh::Director::Models::Network.new(
              name: network.name,
              type: 'manual',
              orphaned: false,
              created_at: Time.now,
            )
            nw.save
            begin
              rollback = {}
              # call cpi to create network subnets
              network.subnets.each do |subnet|
                create_subnet(subnet, nw, rollback)
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
              @logger.info("deleting network #{nw.name}")
              nw.destroy
              raise "deployment failed during creating managed networks: #{e.message}"
            end
          end
        end

        def validate_subnets(network)
          names = {}
          network.subnets.each do |subnet|
            raise 'subnet in managed network must have a name' if subnet.name.nil?
            raise 'subnet names within a managed network must be unique' if names.key?(subnet.name)
            names[subnet.name] = true
          end
        end

        def populate_subnet_properties(subnet, db_subnet)
          subnet.cloud_properties = JSON.parse(db_subnet.cloud_properties)
          subnet.range = NetAddr::CIDR.create(db_subnet.range)
          subnet.gateway = NetAddr::CIDR.create(db_subnet.gateway)
          subnet.netmask = subnet.range.wildcard_mask
          network_id = subnet.range.network(Objectify: true)
          broadcast = subnet.range.version == 6 ? subnet.range.last(Objectify: true) : subnet.range.broadcast(Objectify: true)
          subnet.restricted_ips.add(subnet.gateway.to_i) if subnet.gateway
          subnet.restricted_ips.add(network_id.to_i)
          subnet.restricted_ips.add(broadcast.to_i)
          each_ip(JSON.parse(db_subnet.reserved)) do |ip|
            unless subnet.range.contains?(ip)
              raise NetworkReservedIpOutOfRange,
                    "Reserved IP '#{format_ip(ip)}' is out of " \
                    "subnet '#{subnet.name}' range"
            end
            subnet.restricted_ips.add(ip)
          end
        end

        def create_networks
          return unless Config.network_lifecycle_enabled?
          @logger.info('Network lifecycle check')
          @event_log_stage = Config.event_log.begin_stage('Creating managed networks')
          @deployment_plan.instance_groups.each do |inst_group|
            inst_group.networks.each do |jobnetwork|
              network = jobnetwork.deployment_network
              next unless network.managed?
              with_network_lock(network.name) do
                create_network_if_not_exists(network)
                # the network is in the database
                db_network = Bosh::Director::Models::Network.first(name: network.name)
                if db_network.orphaned
                  db_network.orphaned = false
                  db_network.save
                end
                # add relation between deployment and network
                begin
                  @deployment_plan.model.add_network(db_network)
                rescue Sequel::UniqueConstraintViolation
                  @logger.info('deployment to network relation already exists')
                end
                # fetch the subnet cloud properties from the database
                network.subnets.each do |subnet|
                  db_subnet = db_network.subnets.find { |sn| sn.name == subnet.name }
                  raise('cannot find the subnet in the database') if db_subnet.nil?
                  populate_subnet_properties(subnet, db_subnet)
                end
              end
            end
          end
        end
      end
    end
  end
end
