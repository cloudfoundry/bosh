module Bosh
  module AwsCliPlugin
    class EC2

      NAT_AMI_ID = {
        'us-east-1' => 'ami-f619c29f',      # ami-vpc-nat-1.1.0-beta
        'us-west-1' => 'ami-3bcc9e7e',      # ami-vpc-nat-1.0.0-beta
        'us-west-2' => 'ami-52ff7262',      # ami-vpc-nat-1.0.0-beta
        'eu-west-1' => 'ami-e5e2d991',      # ami-vpc-nat-1.1.0-beta
        'ap-southeast-1' => 'ami-02eb9350', # ami-vpc-nat-1.0.0-beta
        'ap-northeast-1' => 'ami-14d86d15', # ami-vpc-nat-1.0.0-beta
        'ap-southeast-2' => 'ami-ab990e91', # ami-vpc-nat-1.0.0-beta
        'sa-east-1' => 'ami-0039e61d',      # ami-vpc-nat-1.0.0-beta
      }

      attr_reader :elastic_ips

      def initialize(credentials)
        @aws_provider = AwsProvider.new(credentials)
        @elastic_ips = []
      end

      def instances_count
        terminatable_instances.size
      end

      def vpcs
        aws_ec2.vpcs
      end

      def dhcp_options
        aws_ec2.dhcp_options
      end

      def allocate_elastic_ips(count)
        count.times do
          @elastic_ips << allocate_elastic_ip.public_ip
        end
        #say "\tallocated #{eip.public_ip}".make_green
      end

      def allocate_elastic_ip
        aws_ec2.elastic_ips.allocate(vpc: true)
      end

      def release_elastic_ips(ips)
        aws_ec2.elastic_ips.each { |ip| ip.release if ips.include? ip.public_ip }
      end

      def release_all_elastic_ips
        releasable_elastic_ips.map(&:release)
      end

      def create_internet_gateway
        aws_ec2.internet_gateways.create
      end

      def internet_gateway_ids
        aws_ec2.internet_gateways.map(&:id)
      end

      def delete_internet_gateways(ids)
        Array(ids).each do |id|
          gw = aws_ec2.internet_gateways[id]
          gw.attachments.map(&:delete)
          gw.delete
        end
      end

      def create_instance(options)
        aws_ec2.instances.create(options)
      end

      def create_nat_instance(options)
        name = options["name"]
        key_pair = select_key_pair_for_instance(name, options["key_name"])


        instance_options = {
            image_id: NAT_AMI_ID[aws_provider.region],
            instance_type: options.fetch("instance_type", "m1.medium"),
            subnet: options["subnet_id"],
            private_ip_address: options["ip"],
            security_groups: [options["security_group"]],
            key_name: key_pair
        }

        create_instance(instance_options).tap do |instance|
          Bosh::AwsCloud::ResourceWait.for_instance(instance: instance, state: :running)

          instance.add_tag("Name", {value: name})

          elastic_ip = allocate_elastic_ip

          ignorable_errors = [
            AWS::EC2::Errors::InvalidAddress::NotFound,
            AWS::EC2::Errors::InvalidAllocationID::NotFound,
          ]

          Bosh::Common.retryable(tries: 30, on: ignorable_errors) do
            instance.associate_elastic_ip(elastic_ip)
            true
          end

          disable_src_dest_checking(instance.id)
        end
      end

      def disable_src_dest_checking(instance_id)
        aws_ec2.client.modify_instance_attribute(
            :instance_id => instance_id,
            :source_dest_check => {:value => false}
        )
      end

      def terminate_instances
        terminatable_instances.each(&:terminate)
        1.upto(100) do
          break if terminatable_instances.empty?
          sleep 4
        end
        terminatable_instances.empty?
      end

      def instance_names
        terminatable_instances.inject({}) do |memo, instance|
          memo[instance.instance_id] = instance.tags["Name"] || '<unnamed instance>'
          memo
        end
      end

      def get_running_instance_by_name(name)
        instances = aws_ec2.instances.select { |instance| instance.tags["Name"] == name && instance.status == :running }
        raise "More than one running instance with name '#{name}'." if instances.count > 1
        instances.first
      end

      def terminatable_instance_names
        terminatable_instances.inject({}) do |memo, instance|
          memo[instance.instance_id] = instance.tags["Name"]
          memo
        end
      end

      def delete_volumes
        unattached_volumes.each do |vol|
          begin
            vol.delete
          rescue AWS::EC2::Errors::InvalidVolume::NotFound
            # ignored
          end
        end
      end

      def volume_count
        unattached_volumes.count
      end

      def add_key_pair(name, path_to_public_private_key)
        private_key_path = path_to_public_private_key.gsub(/\.pub$/, '')
        public_key_path = "#{private_key_path}.pub"

        if !File.exist?(private_key_path)
          system "ssh-keygen", "-q", '-N', "", "-t", "rsa", "-f", private_key_path
        end

        unless key_pair_by_name(name).nil?
          err "Key pair #{name} already exists on AWS"
        end

        aws_ec2.key_pairs.import(name, File.read(public_key_path))
      end

      def key_pair_by_name(name)
        key_pairs.detect { |kp| kp.name == name }
      end

      def key_pairs
        aws_ec2.key_pairs.to_a
      end

      def force_add_key_pair(name, path_to_public_private_key)
        remove_key_pair(name)
        add_key_pair(name, path_to_public_private_key)
      end

      def remove_key_pair(name)
        key_pair = key_pair_by_name(name)
        key_pair.delete unless key_pair.nil?
        Bosh::Common.retryable(tries: 15) do
          key_pair_by_name(name).nil?
        end
      end

      def remove_all_key_pairs
        aws_ec2.key_pairs.each(&:delete)

        Bosh::Common.retryable(tries: 10) do
          aws_ec2.key_pairs.to_a.empty?
        end
      end

      def delete_all_security_groups
        dsg = deletable_security_groups

        # Revoke all permissions before deleting because a permission can reference
        # another security group, causing a delete to fail
        dsg.each do |sg|
          sg.ingress_ip_permissions.map(&:revoke)
          sg.egress_ip_permissions.map(&:revoke)
        end

        dsg.each do |sg|
          sg.delete unless (sg.name == "default" && !sg.vpc_id)
        end
      end

      private

      attr_reader :aws_provider

      def aws_ec2
        aws_provider.ec2
      end

      def terminatable_instances
        aws_ec2.instances.reject do |i|
          begin
            i.api_termination_disabled? || i.status.to_s == "terminated"
          rescue AWS::Core::Resource::NotFound
            # ignoring instances which disappear while we are going through them
          end
        end
      end

      def releasable_elastic_ips
        ti = terminatable_instances.map(&:id)
        aws_ec2.elastic_ips.select { |eip| eip.instance_id.nil? || ti.include?(eip.instance_id) }
      end

      def deletable_security_groups
        aws_ec2.security_groups.reject { |sg| security_group_in_use?(sg) }
      end

      def security_group_in_use?(sg)
        sg.instances.any? { |s| s.api_termination_disabled? }
      end

      def unattached_volumes
        # only check volumes that don't have status 'deleting' and 'deleted'
        aws_ec2.volumes.filter('status', %w[available creating in_use error]).
            reject { |v| v.attachments.any? }
      end

      def select_key_pair_for_instance(name, key_pair)
        if key_pair.nil?
          if key_pairs.count > 1
            raise "AWS key pair name unspecified for instance '#{name}', unable to select a default."
          elsif key_pairs.count == 0
            raise "AWS key pair name unspecified for instance '#{name}', no key pairs available to select a default."
          else
            key_pair = key_pairs.first.name
          end
        else
          if key_pairs.none? { |kp| kp.name == key_pair }
            raise "No such key pair '#{key_pair}' on AWS."
          end
        end

        key_pair
      end
    end
  end
end
