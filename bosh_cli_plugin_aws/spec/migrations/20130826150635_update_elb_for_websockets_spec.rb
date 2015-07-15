require 'spec_helper'
require '20130826150635_update_elb_for_websockets'

describe UpdateElbForWebsockets do
  include MigrationSpecHelper

  subject { UpdateElbForWebsockets.new(config, '') }

  it "configures elb and security group for websockets" do
    receipt = YAML.load_file(asset "test-output.yml")
    allow(subject).to receive_messages(load_receipt: receipt)

    mock_vpc = double(Bosh::AwsCliPlugin::VPC)
    mock_sg = double(AWS::EC2::SecurityGroup)

    allow(Bosh::AwsCliPlugin::VPC).to receive(:find).with(ec2, receipt['vpc']['id']).and_return(mock_vpc)
    allow(mock_vpc).to receive(:security_group_by_name).with('web').and_return(mock_sg)

    expect(UpdateElbForWebsockets::WebSocketElbHelpers).to receive(:authorize_ingress).with(mock_sg, {"protocol" => "tcp", "ports" => "4443", "sources" => "0.0.0.0/0"}).and_return(true)
    expect(UpdateElbForWebsockets::WebSocketElbHelpers).to receive(:record_ingress).with(receipt, 'web', {"protocol" => "tcp", "ports" => "4443", "sources" => "0.0.0.0/0"})

    mock_elb = double(AWS::ELB::LoadBalancer)
    allow(elb).to receive(:find_by_name).and_return(mock_elb)

    params = {port: 443, protocol: :https}
    fake_cert = double(AWS::IAM::ServerCertificate)
    allow(UpdateElbForWebsockets::WebSocketElbHelpers).to receive(:find_server_certificate_from_listeners).with(mock_elb, params).and_return(fake_cert)

    params = {port: 4443, protocol: :ssl, instance_port: 80, instance_protocol: :tcp, server_certificate: fake_cert}
    expect(UpdateElbForWebsockets::WebSocketElbHelpers).to receive(:create_listener).with(mock_elb, params)

    expect { subject.execute }.to_not raise_error
  end


  describe "validate_receipt" do
    it "skips configuration if elb doesn't exist" do
      allow(subject).to receive_messages(load_receipt: {})
      expect { subject.execute }.to raise_error Bosh::Cli::CliError, /Unable to find `cfrouter'/
    end

    it "skips configuration if vpc isn't in the receipt" do
      receipt = YAML.load_file(asset "test-output.yml")
      receipt.delete('vpc')
      allow(subject).to receive_messages(load_receipt: receipt)

      expect { subject.execute }.to raise_error Bosh::Cli::CliError, /Unable to find VPC ID in AWS VPC Receipt/
    end

    it "skips configuration if elb security group isn't in receipt" do
      receipt = YAML.load_file(asset "test-output.yml")
      receipt['original_configuration']['vpc']['elbs']['cfrouter'].delete('security_group')
      allow(subject).to receive_messages(load_receipt: receipt)

      expect { subject.execute }.to raise_error Bosh::Cli::CliError, /Unable to find `cfrouter' ELB Security Group in AWS VPC Receipt/
    end
  end

  describe UpdateElbForWebsockets::WebSocketElbHelpers do
    before do
      @receipt = YAML.load_file(asset "test-output.yml")
      allow(subject).to receive_messages(load_receipt: @receipt)

      @mock_vpc = double(Bosh::AwsCliPlugin::VPC)
      allow(Bosh::AwsCliPlugin::VPC).to receive(:find).with(ec2, @receipt['vpc']['id']).and_return(@mock_vpc)
    end

    describe ".find_security_group_by_name" do
      it "errors if the group can't be found" do
        allow(@mock_vpc).to receive(:security_group_by_name).with('web').and_return(nil)

        expect {
          UpdateElbForWebsockets::WebSocketElbHelpers.find_security_group_by_name(ec2, @receipt['vpc']['id'], 'web')
        }.to raise_error Bosh::Cli::CliError, /security group web does not exist/
      end

      it "returns the security group with that name" do
        mock_sg = double(AWS::EC2::SecurityGroup)
        allow(@mock_vpc).to receive(:security_group_by_name).with('web').and_return(mock_sg)

        expect(UpdateElbForWebsockets::WebSocketElbHelpers.find_security_group_by_name(ec2, @receipt['vpc']['id'], 'web')).to eq mock_sg
      end
    end

    describe ".authorize_ingress" do
      let(:security_group) { double(AWS::EC2::SecurityGroup) }

      it "authorizes the ingress through the security group" do
        expect(security_group).to receive(:authorize_ingress).with("protocol", 4443, "sources")
        expect(UpdateElbForWebsockets::WebSocketElbHelpers.authorize_ingress(security_group, 'protocol' => "protocol", 'ports' => "4443", 'sources' => "sources")).to be(true)
      end

      it "does not error if ingress rule already exists" do
        expect(security_group).to receive(:authorize_ingress).with("protocol", 4443, "sources").and_raise(AWS::EC2::Errors::InvalidPermission::Duplicate)
        expect(UpdateElbForWebsockets::WebSocketElbHelpers.authorize_ingress(security_group, 'protocol' => "protocol", 'ports' => "4443", 'sources' => "sources")).to be(false)
      end
    end

    describe "record_ingress" do
      it "changes the given vpc_receipt to reflect the added listener" do
        vpc_receipt = {
            'original_configuration' => {
                'vpc' => {
                    'security_groups' => [{
                        'name' => "GROUP_NAME",
                        'ingress' => []
                    }]
                }
            }
        }

        UpdateElbForWebsockets::WebSocketElbHelpers.record_ingress(vpc_receipt, "GROUP_NAME", some: "hash")

        expect(vpc_receipt).to eq ({
            'original_configuration' => {
                'vpc' => {
                    'security_groups' => [{
                        'name' => "GROUP_NAME",
                        'ingress' => [{some: "hash"}]
                    }]
                }
            }
        })
      end
    end

    describe ".find_server_certificate_from_listeners" do
      let(:mock_elb) { double(AWS::ELB::LoadBalancer, name: "cfrouter") }
      let(:mock_listener) { double(AWS::ELB::Listener) }

      it "should find a certificate from listeners with given elb and params" do
        mock_certificate = double(AWS::IAM::ServerCertificate)
        expect(mock_elb).to receive(:listeners).and_return([mock_listener])
        expect(mock_listener).to receive(:port).and_return(443)
        expect(mock_listener).to receive(:protocol).and_return(:https)
        expect(mock_listener).to receive(:server_certificate).twice.and_return(mock_certificate)

        expect(UpdateElbForWebsockets::WebSocketElbHelpers.find_server_certificate_from_listeners(mock_elb, port: 443, protocol: :https)).to eq mock_certificate
      end

      it "errors if listener can't be found" do
        expect(mock_elb).to receive(:listeners).and_return([mock_listener])
        allow(mock_listener).to receive_messages(port: 80, protocol: :http)

        expect {
          UpdateElbForWebsockets::WebSocketElbHelpers.find_server_certificate_from_listeners(mock_elb, port: 443, protocol: :https)
        }.to raise_error Bosh::Cli::CliError, /Could not find listener with params `{:port=>443, :protocol=>:https}' on ELB `cfrouter'/
      end

      it "errors if server certificate can't be found" do
        expect(mock_elb).to receive(:listeners).and_return([mock_listener])
        allow(mock_listener).to receive_messages(port: 443, protocol: :https)
        expect(mock_listener).to receive(:server_certificate).and_return(nil)

        expect {
          UpdateElbForWebsockets::WebSocketElbHelpers.find_server_certificate_from_listeners(mock_elb, port: 443, protocol: :https)
        }.to raise_error Bosh::Cli::CliError, /Could not find server certificate for listener with params `{:port=>443, :protocol=>:https}' on ELB `cfrouter'/
      end

    end

    describe ".create_listener" do
      it "creates a listener on given ELB with specified params" do
        mock_elb = double(AWS::ELB::LoadBalancer, name: "cfrouter")
        mock_listeners = double(AWS::ELB::ListenerCollection)
        params = {port: 4443, protocol: :ssl, instance_port: 80, instance_protocol: :tcp, server_certificate: 'foo'}

        expect(mock_elb).to receive(:listeners).and_return(mock_listeners)
        expect(mock_listeners).to receive(:create).with(params)

        UpdateElbForWebsockets::WebSocketElbHelpers.create_listener(mock_elb, params)
      end

    end
  end
end
