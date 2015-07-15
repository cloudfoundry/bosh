require 'spec_helper'

module Bosh::AwsCliPlugin
  describe VpcDestroyer do
    subject(:vpc_destroyer) { Bosh::AwsCliPlugin::VpcDestroyer.new(ui, config) }
    let(:ui) { instance_double('Bosh::Cli::Command::AWS') }
    let(:config) { { 'aws' => { fake: 'aws config' } } }

    describe '#delete_all' do
      before { allow(Bosh::AwsCliPlugin::EC2).to receive(:new).with(fake: 'aws config').and_return(ec2) }
      let(:ec2) { instance_double('Bosh::AwsCliPlugin::EC2') }

      context 'when there is at least one vpc' do
        before { allow(ec2).to receive(:vpcs).and_return([aws_vpc, aws_vpc2]) }
        let(:aws_vpc) { instance_double('AWS::EC2::VPC', id: 'fake-vpc-id-1') }
        let(:aws_vpc2) { instance_double('AWS::EC2::VPC', id: 'fake-vpc-id-2') }

        before do
          allow(Bosh::AwsCliPlugin::VPC).to receive(:find).with(ec2, 'fake-vpc-id-1').and_return(vpc)
          allow(Bosh::AwsCliPlugin::VPC).to receive(:find).with(ec2, 'fake-vpc-id-2').and_return(vpc2)
        end
        let(:vpc) { instance_double('Bosh::AwsCliPlugin::VPC', vpc_id: 'fake-vpc-id-1') }
        let(:vpc2) { instance_double('Bosh::AwsCliPlugin::VPC', vpc_id: 'fake-vpc-id-2') }

        before do
          allow(vpc).to receive(:dhcp_options).and_return(vpc_aws_dhcp_options)
          allow(vpc2).to receive(:dhcp_options).and_return(vpc_2_aws_dhcp_options)
        end
        let(:vpc_aws_dhcp_options) { instance_double('AWS::EC2::DHCPOptions', id: 'fake-dhcp-options-id-1') }
        let(:vpc_2_aws_dhcp_options) { instance_double('AWS::EC2::DHCPOptions', id: 'fake-dhcp-options-id-2') }

        context 'when user confirms deletion' do
          before { allow(ui).to receive(:confirmed?).and_return(true, false, true) }

          context 'when a vpc has at least one instance' do
            before { allow(vpc).to receive(:instances_count).and_return(1) }

            it 'raises an error' do
              expect {
                vpc_destroyer.delete_all
              }.to raise_error(/instance\(s\) running/)
            end
          end

          context 'when no vpc has any instances' do
            before do
              allow(vpc).to receive(:instances_count).and_return(0)
              allow(vpc2).to receive(:instances_count).and_return(0)
              allow(ec2).to receive(:internet_gateway_ids).and_return('fake-gateway-ids')
            end

            context "when the user confirms deletion" do
              it 'deletes each vpc the user confirmed deletion for' do
                expect(vpc).not_to receive(:delete_network_interfaces)
                expect(vpc).not_to receive(:delete_security_groups)
                expect(vpc).not_to receive(:delete_subnets)
                expect(vpc).not_to receive(:delete_route_tables)
                expect(vpc).not_to receive(:delete_vpc)
                expect(vpc_aws_dhcp_options).not_to receive(:delete)

                expect(vpc2).to receive(:delete_network_interfaces)
                expect(vpc2).to receive(:delete_security_groups)
                expect(vpc2).to receive(:delete_subnets)
                expect(vpc2).to receive(:delete_route_tables)
                expect(vpc2).to receive(:delete_vpc)

                expect(ec2).to receive(:delete_internet_gateways).with('fake-gateway-ids')
                expect(vpc_2_aws_dhcp_options).to receive(:delete)

                vpc_destroyer.delete_all
              end
            end
          end
        end

        context 'when user does not confirm deletion' do
          before { allow(ui).to receive(:confirmed?).and_return(false) }

          it 'does not delete any vps resource' do
            expect(vpc).not_to receive(:delete_network_interfaces)
            expect(vpc).not_to receive(:delete_security_groups)
            expect(vpc).not_to receive(:delete_subnets)
            expect(vpc).not_to receive(:delete_route_tables)
            expect(vpc).not_to receive(:delete_vpc)

            expect(vpc2).not_to receive(:delete_network_interfaces)
            expect(vpc2).not_to receive(:delete_security_groups)
            expect(vpc2).not_to receive(:delete_subnets)
            expect(vpc2).not_to receive(:delete_route_tables)
            expect(vpc2).not_to receive(:delete_vpc)

            expect(ec2).not_to receive(:delete_internet_gateways)
            expect(vpc_aws_dhcp_options).not_to receive(:delete)

            vpc_destroyer.delete_all
          end
        end
      end
    end
  end
end
