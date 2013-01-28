module Bosh
  module Aws
    class EC2
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

      private

      def aws_ec2
        @aws_ec2 ||= ::AWS::EC2.new(@credentials)
      end
    end
  end
end
