require 'spec_helper'

module Bosh::Aws
  describe VpcDestroyer do
    subject(:vpc_destroyer) { Bosh::Aws::VpcDestroyer.new(ui, config) }
    let(:ui) { instance_double('Bosh::Cli::Command::AWS') }
    let(:config) { { 'aws' => { fake: 'aws config' } } }

    describe '#delete_all' do
      before { Bosh::Aws::EC2.stub(:new).with(fake: 'aws config').and_return(ec2) }
      let(:ec2) { instance_double('Bosh::Aws::EC2') }

      context 'when there is at least one vpc' do
        before { ec2.stub(vpcs: [aws_vpc]) }
        let(:aws_vpc) { instance_double('AWS::EC2::VPC', id: 'fake-vpc-id') }

        before { Bosh::Aws::VPC.stub(:find).with(ec2, 'fake-vpc-id').and_return(vpc) }
        let(:vpc) { instance_double('Bosh::Aws::VPC', vpc_id: 'fake-vpc-id') }

        before { vpc.stub(dhcp_options: aws_dhcp_options) }
        let(:aws_dhcp_options) { instance_double('AWS::EC2::DHCPOptions', id: 'fake-dhcp-options-id') }

        context 'when user confirms deletion' do
          before { ui.stub(confirmed?: true) }

          context 'when vpc has at least one instance' do
            before { vpc.stub(instances_count: 1) }

            it 'raises an error' do
              expect {
                vpc_destroyer.delete_all
              }.to raise_error(/instance\(s\) running/)
            end
          end

          context 'when vpc does not have any instances' do
            before { vpc.stub(instances_count: 0) }

            it 'delete any vps resource' do
              ec2.stub(internet_gateway_ids: 'fake-gateway-ids')

              vpc.should_receive(:delete_network_interfaces)
              vpc.should_receive(:delete_security_groups)
              ec2.should_receive(:delete_internet_gateways).with('fake-gateway-ids')
              vpc.should_receive(:delete_subnets)
              vpc.should_receive(:delete_route_tables)
              vpc.should_receive(:delete_vpc)
              aws_dhcp_options.should_receive(:delete)
              vpc_destroyer.delete_all
            end
          end
        end

        context 'when user does not confirm deletion' do
          before { ui.stub(confirmed?: false) }

          it 'does not delete any vps resource' do
            vpc.should_not_receive(:delete_network_interfaces)
            vpc.should_not_receive(:delete_security_groups)
            ec2.should_not_receive(:delete_internet_gateways)
            vpc.should_not_receive(:delete_subnets)
            vpc.should_not_receive(:delete_route_tables)
            vpc.should_not_receive(:delete_vpc)
            aws_dhcp_options.should_not_receive(:delete)
            vpc_destroyer.delete_all
          end
        end
      end
    end
  end
end
