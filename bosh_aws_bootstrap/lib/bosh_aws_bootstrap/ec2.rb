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
        aws_ec2.instances.count
      end

      def vpcs
        aws_ec2.vpcs
      end

      def dhcp_options
        aws_ec2.dhcp_options
      end

      def allocate_elastic_ips(count)
        count.times do
          elastic_ip = aws_ec2.elastic_ips.allocate(vpc: true)
          @elastic_ips << elastic_ip.public_ip
        end
        #say "\tallocated #{eip.public_ip}".green
      end

      def release_elastic_ips(ips)
        aws_ec2.elastic_ips.each { |ip| ip.release if ips.include? ip.public_ip }
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

      def terminate_instances
        aws_ec2.instances.each &:terminate
      end

      def instance_names
        aws_ec2.instances.inject({}) do |memo, instance|
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
        private_key_path = path_to_public_private_key.gsub(/.pub$/, '')
        public_key_path = "#{private_key_path}.pub"
        if !File.exist?(private_key_path)
          system "ssh-keygen", "-q", '-N', "", "-t", "rsa", "-f", private_key_path
        end

        aws_ec2.key_pairs.import(name, File.read(public_key_path))
      rescue AWS::EC2::Errors::InvalidKeyPair::Duplicate => e
        err "Key pair #{name} already exists on AWS".red
      end

      def remove_key_pair(name)
        aws_ec2.key_pairs[name].delete
      end

      private

      def aws_ec2
        @aws_ec2 ||= ::AWS::EC2.new(@credentials)
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
