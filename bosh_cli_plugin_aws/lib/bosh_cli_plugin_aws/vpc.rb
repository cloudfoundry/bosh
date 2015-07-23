module Bosh
  module AwsCliPlugin
    class VPC

      DEFAULT_CIDR = "10.0.0.0/16"
      DEFAULT_ROUTE = "0.0.0.0/0"
      NAT_INSTANCE_DEFAULTS = {
          :image_id => "ami-f619c29f",
          :instance_type => "m1.medium"
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

      def make_internet_gateway_default_route_for_subnet(subnet)
        route_table = @aws_vpc.route_tables.create
        route_table.create_route(DEFAULT_ROUTE, internet_gateway: @aws_vpc.internet_gateway)
        subnet.route_table = route_table
      end

      def make_nat_instance_default_route_for_subnet(subnet, nat_instance)
        route_table = @aws_vpc.route_tables.create
        route_table.create_route(DEFAULT_ROUTE, instance: nat_instance)
        subnet.route_table = route_table
      end

      def vpc_id
        @aws_vpc.id
      end

      def cidr_block
        @aws_vpc.cidr_block
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

      def delete_vpc
        @aws_vpc.delete
        Bosh::Common.retryable(tries: 30, sleep: 5, on: []) do
          begin
            false if @aws_vpc.state
          rescue AWS::EC2::Errors::InvalidVpcID::NotFound
            true
          end
        end

      rescue ::AWS::EC2::Errors::DependencyViolation
        err "#{@aws_vpc.id} has dependencies that this tool does not delete"
      end

      def create_security_groups(groups_specs)
        groups_specs.each do |group_spec|
          if group_name_available group_spec["name"]
            security_group = @aws_vpc.security_groups.create(group_spec["name"])
            Bosh::AwsCloud::ResourceWait.for_sgroup(sgroup: security_group, state: true)

            group_spec["ingress"].each do |ingress|
              range_match = ingress["ports"].to_s.match(/(\d+)\s*-\s*(\d+)/)
              ports = range_match ? (range_match[1].to_i)..(range_match[2].to_i) : ingress["ports"].to_i

              # Wait for eventual consistancy
              ignorable_errors = [AWS::EC2::Errors::InvalidGroup::NotFound]

              Bosh::Common.retryable(tries: 30, on: ignorable_errors) do
                security_group.authorize_ingress(ingress["protocol"], ports, ingress["sources"])
                true
              end
            end
          end
        end
      end

      def delete_security_groups
        @aws_vpc.security_groups.reject { |group| group.name == "default" }.each(&:delete)
      end

      def security_group_by_name(name)
        @aws_vpc.security_groups.detect { |sg| sg.name == name }
      end

      def create_subnets(subnets)
        subnets.each_pair do |name, subnet_spec|
          yield "Making subnet #{name} #{subnet_spec["cidr"]}:" if block_given?
          options = {}
          options[:availability_zone] = subnet_spec["availability_zone"] if subnet_spec["availability_zone"]

          subnet = @aws_vpc.subnets.create(subnet_spec["cidr"], options)
          Bosh::AwsCloud::ResourceWait.for_subnet(subnet: subnet, state: :available)

          subnet.add_tag("Name", :value => name)
        end
      end

      def extract_nat_instance_specs(specs)
        subnet_specs_with_nats = specs.select do |_, subnet_spec|
          subnet_spec.has_key?("nat_instance")
        end

        subnet_specs_with_nats.map do |subnet_name, subnet_spec|
          nat_instance_spec = subnet_spec["nat_instance"]
          nat_instance_spec["subnet_id"] = subnets[subnet_name]
          nat_instance_spec
        end
      end

      def create_nat_instances(subnets)
        extract_nat_instance_specs(subnets).each do |subnet_spec|
          @ec2.create_nat_instance(subnet_spec)
        end
      end

      def setup_subnet_routes(subnet_specs)
        subnet_specs.each_pair do |name, subnet_spec|
          if subnet_spec["default_route"]
            subnet = @aws_vpc.subnets[subnets[name]]
            yield "  Making routing table for #{name}" if block_given?
            yield "  Binding default route to #{subnet_spec["default_route"]}" if block_given?
            if subnet_spec["default_route"] == "igw"
              make_internet_gateway_default_route_for_subnet(subnet)
            else
              make_nat_instance_default_route_for_subnet(subnet, @ec2.get_running_instance_by_name(subnet_spec["default_route"]))
            end
          end
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
        #say "\tcreated and associated DHCP options #{new_dhcp_options.id}".make_green

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
        say "unable to delete security group: #{name}: #{e.message}".make_yellow
        false
      end
    end
  end
end
