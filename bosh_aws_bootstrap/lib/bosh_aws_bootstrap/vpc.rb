module Bosh
  module Aws
    class VPC
      include Bosh::AwsCloud::Helpers
      def task_checkpoint; end

      DEFAULT_CIDR = "10.0.0.0/16"

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

      def create_subnets(subnets)
        subnets.each_pair do |name, subnet|
          options = {}
          options[:availability_zone] = subnet["availability_zone"] if subnet["availability_zone"]
          subnet = @aws_vpc.subnets.create(subnet["cidr"], options)
          wait_resource(subnet, :available, :state)
          subnet.add_tag("Name", :value => name)
          #say "\tdone creating subnet: #{subnet["cidr"]}".green
        end
      end

      def delete_subnets
        @aws_vpc.subnets.each(&:delete)
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
