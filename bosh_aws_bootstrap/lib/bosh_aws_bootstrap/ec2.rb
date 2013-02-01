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

      def snapshot_volume(volume, snapshot_name, description, tags = {})
        snap = volume.create_snapshot(description)
        tag(snap, 'Name', snapshot_name)
        tags.each_pair { |key, value| tag(snap, key, value) }
        snap
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
