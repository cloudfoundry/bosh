require 'spec_helper'

describe Bosh::Aws::ELB do
  let(:elb) { described_class.new({"my" => "creds"}) }
  let(:ec2) { Bosh::Aws::EC2.new({}) }
  let(:fake_aws_security_group) { mock("security_group", id: "sg_id", name: "security_group_name") }
  let(:fake_aws_vpc) { mock("vpc", security_groups: [fake_aws_security_group]) }
  let(:vpc) { Bosh::Aws::VPC.new(ec2, fake_aws_vpc) }
  let(:fake_aws_elb) { double("aws_elb", load_balancers: double()) }

  it "creates an underlying AWS ELB object with your credentials" do
    AWS::ELB.should_receive(:new).with({"my" => "creds"}).and_call_original
    elb.send(:aws_elb).should be_kind_of(AWS::ELB)
  end

  describe "creation" do
    let(:new_elb) {mock("a new elb")}
    before do
      elb.stub(:aws_elb).and_return(fake_aws_elb)
      new_elb.should_receive(:configure_health_check).with({
                                                               :healthy_threshold => 5,
                                                               :unhealthy_threshold => 2,
                                                               :interval => 5,
                                                               :timeout => 2,
                                                               :target => "TCP:80"
                                                           })
      vpc.should_receive(:subnets).and_return({"sub_name1" => "sub_id1", "sub_name2" => "sub_id2"})
      vpc.should_receive(:security_group_by_name).with("security_group_name").and_return(fake_aws_security_group)
    end

    it "can create an ELB given a name and a vpc and a CIDR block" do
      fake_aws_elb.load_balancers.should_receive(:create).with("my elb name", {
          :listeners => [{
                             :port => 80,
                             :protocol => :http,
                             :instance_port => 80,
                             :instance_protocol => :http,
                         }],
          :subnets => ["sub_id1", "sub_id2"],
          :security_groups => ["sg_id"]
      }).and_return(new_elb)
      elb.create("my elb name", vpc, "subnets" => %w(sub_name1 sub_name2), "security_group" => "security_group_name").should == new_elb
    end
  end

  describe "deletion" do
    before do
      elb.stub(:aws_elb).and_return(fake_aws_elb)
    end

    it "should call delete on each ELB" do
      elb1 = mock("elb1")
      elb2 = mock("elb2")
      elb1.should_receive(:delete)
      elb2.should_receive(:delete)
      fake_aws_elb.should_receive(:load_balancers).and_return([elb1, elb2])
      elb.delete_elbs
    end
  end

  describe "names" do
    before do
      elb.stub(:aws_elb).and_return(fake_aws_elb)
    end

    it "returns the names of the running ELBs" do
      elb1 = mock("elb1", name: 'one')
      elb2 = mock("elb2", name: 'two')
      fake_aws_elb.should_receive(:load_balancers).and_return([elb1, elb2])
      elb.names.should == ["one", "two"]
    end
  end
end
