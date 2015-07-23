module Bosh
  module AwsCliPlugin
    class AwsProvider
      attr_reader :credentials

      def initialize(credentials)
        @credentials = credentials
      end

      def ec2
        @ec2 ||= ::AWS::EC2.new(credentials.merge('ec2_endpoint' => ec2_endpoint))
      end

      def elb
        @elb ||= ::AWS::ELB.new(credentials.merge('elb_endpoint' => elb_endpoint))
      end

      def iam
        @iam ||= ::AWS::IAM.new(credentials)
      end

      def rds
        @rds ||= ::AWS::RDS.new(credentials.merge('rds_endpoint' => rds_endpoint))
      end

      def rds_client
        @rds_client ||= ::AWS::RDS::Client.new(credentials.merge('rds_endpoint' => rds_endpoint))
      end

      def route53
        @aws_route53 ||= ::AWS::Route53.new(credentials)
      end

      def region
        credentials['region']
      end

      def s3
        @s3 ||= ::AWS::S3.new(credentials)
      end

      private

      def ec2_endpoint
        "ec2.#{region}.amazonaws.com"
      end

      def elb_endpoint
        "elasticloadbalancing.#{region}.amazonaws.com"
      end

      def rds_endpoint
        "rds.#{region}.amazonaws.com"
      end
    end
  end
end
