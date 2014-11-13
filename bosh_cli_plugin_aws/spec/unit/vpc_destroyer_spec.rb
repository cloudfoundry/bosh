require 'spec_helper'

module Bosh::Aws
  describe VpcDestroyer do
    subject(:vpc_destroyer) { Bosh::Aws::VpcDestroyer.new(ui, config) }
    let(:ui) { instance_double('Bosh::Cli::Command::AWS') }
    let(:config) { { 'aws' => { fake: 'aws config' } } }

    describe '#delete_all' do
      before { allow(Bosh::Aws::EC2).to receive(:new).with(fake: 'aws config').and_return(ec2) }
      let(:ec2) { instance_double('Bosh::Aws::EC2') }

      context 'when there is at least one vpc' do
        before { allow(ec2).to receive(:vpcs).and_return([aws_vpc]) }
        let(:aws_vpc) { instance_double('AWS::EC2::VPC', id: 'fake-vpc-id') }

        before { allow(Bosh::Aws::VPC).to receive(:find).with(ec2, 'fake-vpc-id').and_return(vpc) }
        let(:vpc) { instance_double('Bosh::Aws::VPC', vpc_id: 'fake-vpc-id') }

        before { allow(vpc).to receive(:dhcp_options).and_return(aws_dhcp_options) }
        let(:aws_dhcp_options) { instance_double('AWS::EC2::DHCPOptions', id: 'fake-dhcp-options-id') }

        context 'when user confirms deletion' do
          before { allow(ui).to receive(:confirmed?).and_return(true) }

          context 'when vpc has at least one instance' do
            before { allow(vpc).to receive(:instances_count).and_return(1) }

            it 'raises an error' do
              expect {
                vpc_destroyer.delete_all
              }.to raise_error(/instance\(s\) running/)
            end
          end

          context 'when vpc does not have any instances' do
            before { allow(vpc).to receive(:instances_count).and_return(0) }

            it 'delete any vps resource' do
              allow(ec2).to receive(:internet_gateway_ids).and_return('fake-gateway-ids')

              expect(vpc).to receive(:delete_network_interfaces)
              expect(vpc).to receive(:delete_security_groups)
              expect(ec2).to receive(:delete_internet_gateways).with('fake-gateway-ids')
              expect(vpc).to receive(:delete_subnets)
              expect(vpc).to receive(:delete_route_tables)
              expect(vpc).to receive(:delete_vpc)
              expect(aws_dhcp_options).to receive(:delete)

              vpc_destroyer.delete_all
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

            expect(ec2).not_to receive(:delete_internet_gateways)
            expect(aws_dhcp_options).not_to receive(:delete)

            vpc_destroyer.delete_all
          end
        end
      end
    end
  end
end
