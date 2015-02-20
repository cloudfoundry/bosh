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
    allow(ec2).to receive_message_chain(:elastic_ips, :[]).and_return(elastic_ip)
    allow(Bosh::Common).to receive(:sleep)

    expect(instance).to receive(:associate_elastic_ip).and_raise(AWS::EC2::Errors::IncorrectInstanceState)
    expect(instance).to receive(:associate_elastic_ip).with(elastic_ip).and_return(true)

    vip.configure(ec2, instance)
  end

end
