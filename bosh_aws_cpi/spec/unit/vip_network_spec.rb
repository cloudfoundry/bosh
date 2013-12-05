require 'spec_helper'

describe Bosh::AwsCloud::VipNetwork do
  let(:ec2) { double(AWS::EC2) }
  let(:instance) { double(AWS::EC2::Instance, :id => 'id') }

  it 'should require an IP' do
    vip = described_class.new('vip', {})
    expect {
      vip.configure(ec2, instance)
    }.to raise_error Bosh::Clouds::CloudError
  end

  it 'should retry to attach until it succeeds' do
    vip = described_class.new('vip', {'ip' => '1.2.3.4'})

    elastic_ip = double('eip')
    ec2.stub_chain(:elastic_ips, :[]).and_return(elastic_ip)
    Bosh::Common.stub(:sleep)

    instance.should_receive(:associate_elastic_ip).and_raise(AWS::EC2::Errors::IncorrectInstanceState)
    instance.should_receive(:associate_elastic_ip).with(elastic_ip).and_return(true)

    vip.configure(ec2, instance)
  end

end
