module Bosh
  module Aws
    class Migration

      attr_reader :s3, :elb, :ec2, :rds, :route53, :logger, :config

      def initialize(config, receipt_bucket_name)
        @config = config
        @receipt_bucket_name = receipt_bucket_name
        aws_config = config['aws']

        aws_config['ec2_endpoint'] ||= ['ec2', aws_config['region'], 'amazonaws.com'].compact.join('.')
        aws_config['elb_endpoint'] ||= ['elasticloadbalancing', aws_config['region'], 'amazonaws.com'].compact.join('.')
        aws_config['rds_endpoint'] ||= ['rds', aws_config['region'], 'amazonaws.com'].compact.join('.')

        @s3 = S3.new(aws_config)
        @elb = ELB.new(aws_config)
        @ec2 = EC2.new(aws_config)
        @rds = RDS.new(aws_config)
        @route53 = Route53.new(aws_config)
        @logger = Bosh::Clouds::Config.logger
      end

      def run
        say "Executing migration #{self.class.name}"
        execute
      end

      def save_receipt(receipt_name, receipt)
        receipt_yaml = YAML.dump(receipt)
        s3.upload_to_bucket(@receipt_bucket_name, "receipts/#{receipt_name}.yml", receipt_yaml)

        File.open("#{receipt_name}.yml", "w+") do |f|
          f.write(receipt_yaml)
        end

        say "details in S3 receipt: #{receipt_name} and file: #{receipt_name}.yml"
      end

      def load_receipt(receipt_name)
        YAML.load(s3.fetch_object_contents(@receipt_bucket_name, "receipts/#{receipt_name}.yml"))
      end
    end
  end
end