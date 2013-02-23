module Bosh
  module Aws
    class EC2
      MAX_TAG_KEY_LENGTH = 127
      MAX_TAG_VALUE_LENGTH = 255

      attr_reader :elastic_ips

      def initialize(credentials)
        @credentials = credentials
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
        #say "\tallocated #{eip.public_ip}".green
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
        aws_ec2.internet_gateways.map &:id
      end

      def delete_internet_gateways(ids)
        Array(ids).each do |id|
          gw = aws_ec2.internet_gateways[id]
          gw.attachments.map &:delete
          gw.delete
        end
      end

      def create_instance(options)
        aws_ec2.instances.create(options)
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

      def delete_volumes
        unattached_volumes.each &:delete
      end

      def volume_count
        unattached_volumes.count
      end

      def instance_names
        terminatable_instances.inject({}) do |memo, instance|
          memo[instance.instance_id] = instance.tags["Name"] || '<unnamed instance>'
          memo
        end
      end

      def terminatable_instance_names
        terminatable_instances.inject({}) do |memo, instance|
          memo[instance.instance_id] = instance.tags["Name"]
          memo
        end
      end

      def instances_for_ids(ids)
        aws_ec2.instances.filter('instance-id', *ids)
      end

      def snapshot_volume(volume, snapshot_name, description = "", tags = {})
        snap = volume.create_snapshot(description.to_s)
        tag(snap, 'Name', snapshot_name)
        tags.each_pair { |key, value| tag(snap, key.to_s, value) }
        snap
      end

      def add_key_pair(name, path_to_public_private_key)
        private_key_path = path_to_public_private_key.gsub(/\.pub$/, '')
        public_key_path = "#{private_key_path}.pub"
        if !File.exist?(private_key_path)
          system "ssh-keygen", "-q", '-N', "", "-t", "rsa", "-f", private_key_path
        end

        aws_ec2.key_pairs.import(name, File.read(public_key_path))
      rescue AWS::EC2::Errors::InvalidKeyPair::Duplicate => e
        err "Key pair #{name} already exists on AWS".red
      end

      def force_add_key_pair(name, path_to_public_private_key)
        remove_key_pair(name)
        add_key_pair(name, path_to_public_private_key)
      end

      def remove_key_pair(name)
        aws_ec2.key_pairs[name].delete if aws_ec2.key_pairs[name]
      end

      def remove_all_key_pairs
        deletable_key_pairs.map(&:delete)
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

      def aws_ec2
        @aws_ec2 ||= ::AWS::EC2.new(@credentials)
      end

      def terminatable_instances
        aws_ec2.instances.reject{|i| i.api_termination_disabled? || i.status.to_s == "terminated"}
      end

      def releasable_elastic_ips
        ti = terminatable_instances.map(&:id)
        aws_ec2.elastic_ips.select { |eip| eip.instance_id.nil? || ti.include?(eip.instance_id) }
      end

      def deletable_key_pairs
        aws_ec2.key_pairs.reject { |kp| key_pair_in_use?(kp) }
      end

      def key_pair_in_use?(kp)
        aws_ec2.instances.filter('key-name', kp.name).count > 0
      end

      def deletable_security_groups
        aws_ec2.security_groups.reject{ |sg| security_group_in_use?(sg) }
      end

      def security_group_in_use?(sg)
        aws_ec2.instances.filter('group-id', sg.id).count > 0
      end

      def unattached_volumes
        aws_ec2.volumes.reject{|v| v.attachments.any? }
      end

      def tag(taggable, key, value)
        trimmed_key = key[0..(MAX_TAG_KEY_LENGTH - 1)]
        trimmed_value = value[0..(MAX_TAG_VALUE_LENGTH - 1)]
        taggable.add_tag(trimmed_key, :value => trimmed_value)
      rescue AWS::EC2::Errors::InvalidParameterValue => e
        say("could not tag #{taggable.id}: #{e.message}")
      end
    end
  end
end
