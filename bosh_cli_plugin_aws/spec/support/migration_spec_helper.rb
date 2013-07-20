module MigrationSpecHelper
  attr_accessor :s3, :elb, :ec2, :route53, :rds, :config_file, :config

  def self.included(base)
    base.let(:s3) { double("S3") }
    base.let(:elb) { double("ELB") }
    base.let(:ec2) { double("EC2") }
    base.let(:rds) { double("RDS") }
    base.let(:route53) { double("Route 53") }
    base.let(:config_file) { asset "config.yml"}
    base.let(:config) { YAML.load_file(config_file) }
    base.let(:provider) { mock(Bosh::Aws::AwsProvider) }

    base.before do
      Bosh::Aws::S3.stub(:new).and_return(s3)
      Bosh::Aws::ELB.stub(:new).and_return(elb)
      Bosh::Aws::EC2.stub(:new).and_return(ec2)
      Bosh::Aws::RDS.stub(:new).and_return(rds)
      Bosh::Aws::Route53.stub(:new).and_return(route53)
      subject.stub(:load_receipt).and_return(nil)
      subject.stub(:save_receipt)
      subject.stub(:sleep)
    end
  end
end
