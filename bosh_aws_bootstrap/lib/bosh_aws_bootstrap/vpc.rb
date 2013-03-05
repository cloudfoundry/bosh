module Bosh
  module Aws
    class VPC
      include Bosh::AwsCloud::Helpers
      def task_checkpoint; end

      DEFAULT_CIDR = "10.0.0.0/16"
      DEFAULT_ROUTE = "0.0.0.0/0"
      NAT_INSTANCE_DEFAULTS = {
          :key_name => "bosh",
          :image_id => "ami-f619c29f",
          :instance_type => "m1.small"
      }

      def initialize(ec2, aws_vpc)
        @ec2 = ec2
        @aws_vpc = aws_vpc
      end

      def self.create(ec2, cidr = DEFAULT_CIDR, instance_tenancy = nil)
        vpc_options = instance_tenancy ? {instance_tenancy: instance_tenancy} : {}
        self.new(ec2, ec2.vpcs.create(cidr, vpc_options))
      end

      def self.find(ec2, vpc_id)
        self.new(ec2, ec2.vpcs[vpc_id])
      end

      def vpc_id
        @aws_vpc.id
      end

      def instances_count
        @aws_vpc.instances.count
      end

      def dhcp_options
        @aws_vpc.dhcp_options
      end

      def state
        @aws_vpc.state
      end

      def subnets
        Hash[@aws_vpc.subnets.map { |subnet| [subnet.tags["Name"], subnet.id] }]
      end

      def make_route_for_internet_gateway(subnet_id, gateway_id)
        @aws_vpc.subnets[subnet_id].route_table.create_route("0.0.0.0/0", :internet_gateway => gateway_id)
      end

      def delete_vpc
        @aws_vpc.delete
      rescue ::AWS::EC2::Errors::DependencyViolation => e
        err "#{@aws_vpc.id} has dependencies that this tool does not delete"
      end

      def create_security_groups(groups_specs)
        groups_specs.each do |group_spec|
          if group_name_available group_spec["name"]
            security_group = @aws_vpc.security_groups.create(group_spec["name"])
            group_spec["ingress"].each do |ingress|
              range_match = ingress["ports"].to_s.match(/(\d+)\s*-\s*(\d+)/)
              ports = range_match ? (range_match[1].to_i)..(range_match[2].to_i) : ingress["ports"].to_i
              security_group.authorize_ingress(ingress["protocol"], ports, ingress["sources"])
            end
          end
        end
      end

      def delete_security_groups
        @aws_vpc.security_groups.reject { |group| group.name == "default" }.each(&:delete)
      end

      def security_group_by_name(name)
        @aws_vpc.security_groups.detect {|sg| sg.name == name}
      end

      def create_subnets(subnets)
        nat_instances = {}
        subnets.each_pair do |name, subnet_spec|
          yield "Making subnet #{name} #{subnet_spec['cidr']}:" if block_given?
          options = {}
          options[:availability_zone] = subnet_spec["availability_zone"] if subnet_spec["availability_zone"]

          subnet = @aws_vpc.subnets.create(subnet_spec["cidr"], options)
          wait_resource(subnet, :available, :state)

          if subnet_spec["default_route"]
            yield "  Making routing table" if block_given?
            route_table = @aws_vpc.route_tables.create
            subnet.route_table = route_table
            yield "  Binding default route to #{subnet_spec["default_route"]}" if block_given?
            if subnet_spec["default_route"] == "igw"
              route_table.create_route(DEFAULT_ROUTE, :internet_gateway => @aws_vpc.internet_gateway)
            else
              nat_box_name = subnet_spec["default_route"]
              nat_inst = nat_instances[nat_box_name] || raise("cannot find nat instance #{nat_box_name}")
              route_table.create_route(DEFAULT_ROUTE, :instance => nat_inst)
            end
          end

          if subnet_spec["nat_instance"]
            nat_instance_options = NAT_INSTANCE_DEFAULTS.merge(
                {
                    :security_groups => [subnet_spec["nat_instance"]["security_group"]] ||
                        raise("nat_instance in subnet #{name} needs a 'security_group' key"),
                    :subnet => subnet.id,
                    :private_ip_address => subnet_spec["nat_instance"]["ip"] ||
                        raise("nat_instance in subnet #{name} needs an 'ip' key")
                })
            yield "  Booting nat instance" if block_given?
            inst = @ec2.create_instance(nat_instance_options)
            eip = @ec2.allocate_elastic_ip
            yield "  Waiting for nat instance to be running" if block_given?
            wait_resource(inst, :running, :status)
            inst.add_tag("Name", {:value => subnet_spec["nat_instance"]["name"]})
            yield "  Attaching elastic IP" if block_given?
            inst.associate_elastic_ip(eip)
            @ec2.disable_src_dest_checking(inst.id)
            nat_instances[subnet_spec["nat_instance"]["name"] || raise("nat_instance in subnet #{name} needs a 'name' key")] = inst
          end

          subnet.add_tag("Name", :value => name)
          yield "  Done" if block_given?
        end
      end

      def delete_subnets
        @aws_vpc.subnets.each(&:delete)
      end

      def delete_route_tables
        @aws_vpc.route_tables.reject(&:main?).each(&:delete)
      end

      def delete_network_interfaces
        @aws_vpc.network_interfaces.each(&:delete)
      end

      def create_dhcp_options(options)
        default_dhcp_opts = @aws_vpc.dhcp_options

        new_dhcp_options = @ec2.dhcp_options.create(options)
        new_dhcp_options.associate(vpc_id)
        #say "\tcreated and associated DHCP options #{new_dhcp_options.id}".green

        default_dhcp_opts.delete
      end

      def attach_internet_gateway(gateway_id)
        @aws_vpc.internet_gateway = gateway_id
      end

      private

      def group_name_available(name)
        @aws_vpc.security_groups.each { |group| group.delete if group.name == name }
        true
      rescue ::AWS::EC2::Errors::DependencyViolation => e
        say "unable to delete security group: #{name}: #{e.message}".yellow
        false
      end
    end
  end
end
