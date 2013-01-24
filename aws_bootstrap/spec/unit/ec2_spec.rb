require 'spec_helper'

describe Bosh::Aws::EC2 do
  let(:ec2) { described_class.new({}) }

  describe "elastic IPs" do
    describe "allocation" do
      it "can allocate a given number of elastic IPs" do
        fake_elastic_ip_collection = double("elastic_ips")
        ec2.stub(:aws_ec2).and_return(double("fake_aws_ec2", elastic_ips: fake_elastic_ip_collection))
        fake_elastic_ip_collection.stub(:allocate).and_return(double("elastic_ip").as_null_object)

        fake_elastic_ip_collection.should_receive(:allocate).with(vpc: true).exactly(5).times

        ec2.allocate_elastic_ips(5)
      end

      it "populates the elastic_ips variable with the newly created IPs" do
        fake_elastic_ip_collection = double("elastic_ips")
        ec2.stub(:aws_ec2).and_return(double("fake_aws_ec2", elastic_ips: fake_elastic_ip_collection))
        elastic_ip_1 = double("elastic_ip", public_ip: "1.2.3.4")
        elastic_ip_2 = double("elastic_ip", public_ip: "5.6.7.8")

        fake_elastic_ip_collection.stub(:allocate).and_return(elastic_ip_1, elastic_ip_2)

        ec2.elastic_ips.should == []

        ec2.allocate_elastic_ips(2)

        ec2.elastic_ips.should =~ ["1.2.3.4", "5.6.7.8"]
      end
    end

    describe "release" do
      it "can release the given IPs" do
        elastic_ip_1 = double("elastic_ip", public_ip: "1.2.3.4")
        elastic_ip_2 = double("elastic_ip", public_ip: "5.6.7.8")
        fake_aws_ec2 = double("aws_ec2", elastic_ips: [elastic_ip_1, elastic_ip_2])

        ec2.stub(:aws_ec2).and_return(fake_aws_ec2)

        elastic_ip_1.should_receive :release
        elastic_ip_2.should_not_receive :release

        ec2.release_elastic_ips ["1.2.3.4"]
      end
    end
  end
end