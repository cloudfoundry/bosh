module MigrationSpecHelper
  attr_accessor :s3, :elb, :ec2, :route53, :rds, :config_file, :config

  def self.included(base)

    base.before do
      self.s3 = double("S3")
      self.elb = double("ELB")
      self.ec2 = double("EC2")
      self.ec2 = double("EC2")
      self.rds = double("RDS")
      self.route53 = double("Route 53")

      self.config_file = asset "config.yml"
      self.config = YAML.load_file(config_file)

      allow(Bosh::AwsCliPlugin::S3).to receive(:new).and_return(s3)
      allow(Bosh::AwsCliPlugin::ELB).to receive(:new).and_return(elb)
      allow(Bosh::AwsCliPlugin::EC2).to receive(:new).and_return(ec2)
      allow(Bosh::AwsCliPlugin::RDS).to receive(:new).and_return(rds)
      allow(Bosh::AwsCliPlugin::Route53).to receive(:new).and_return(route53)

      allow(subject).to receive(:load_receipt).and_return(nil)
      allow(subject).to receive(:save_receipt)
      allow(subject).to receive(:sleep)
    end
  end
end
