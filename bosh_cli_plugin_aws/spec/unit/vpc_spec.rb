require 'spec_helper'

describe Bosh::Aws::VPC do
  describe 'VPC' do
    describe 'creation' do
      it 'can create a VPC given a cidr and instance_tenancy' do
        fake_vpc_collection = double('vpcs')
        fake_ec2 = double('ec2', vpcs: fake_vpc_collection)

        fake_vpc_collection.
            should_receive(:create).
            with('cider', {instance_tenancy: 'house rules'}).
            and_return(double('aws_vpc', id: 'vpc-1234567'))

        described_class.create(fake_ec2, 'cider', 'house rules').vpc_id.should == 'vpc-1234567'
      end
    end

    describe 'find' do
      it 'can find a VPC with vpc_id' do
        fake_vpc_collection = double('vpcs')
        fake_ec2 = double('ec2', vpcs: fake_vpc_collection)

        fake_vpc_collection.should_receive(:[]).with('vpc-1234567').and_return(double('aws_vpc', id: 'vpc-1234567'))

        described_class.find(fake_ec2, 'vpc-1234567').vpc_id.should == 'vpc-1234567'
      end
    end

    describe 'deletion' do
      it 'can delete the VPC' do
        fake_aws_vpc = double('aws_vpc')
        fake_aws_vpc.should_receive :delete
        fake_aws_vpc.should_receive(:state).and_raise(AWS::EC2::Errors::InvalidVpcID::NotFound)

        Bosh::Aws::VPC.new(double('ec2'), fake_aws_vpc).delete_vpc
      end

      it 'throws a nice error message when unable to delete the VPC' do
        fake_aws_vpc = double('aws_vpc', id: 'boshIsFun')

        fake_aws_vpc.should_receive(:delete).and_raise(::AWS::EC2::Errors::DependencyViolation)

        expect {
          Bosh::Aws::VPC.new(double('ec2'), fake_aws_vpc).delete_vpc
        }.to raise_error('boshIsFun has dependencies that this tool does not delete')
      end
    end
  end

  describe 'subnets' do
    describe 'creation' do
      let(:fake_aws_vpc) { double('aws_vpc', subnets: double('subnets')) }
      let(:fake_ec2) { double('ec2') }
      let(:vpc) { Bosh::Aws::VPC.new(fake_ec2, fake_aws_vpc).tap { |v| v.stub(:sleep) } }
      let(:sub1) { double('sub1', id: 'amz-sub1') }
      let(:tables) { double('route_tables') }
      let(:new_table) { double('route_table') }

      before do
        sub1.should_receive(:state).and_return(:pending, :available)
        sub1.should_receive(:add_tag).with('Name', :value => 'sub1')
      end

      xit 'can create subnets with the specified CIDRs, tags, and AZs' do
        subnet_1_specs = {'cidr' => 'cider', 'availability_zone' => 'canada'}
        subnet_2_specs = {'cidr' => 'cedar'}
        sub2 = double('sub2')

        sub1.stub(:state).and_return(:pending, :available)
        sub2.stub(:state).and_return(:pending, :available)

        sub1.should_receive(:add_tag).with('Name', :value => 'sub1')
        sub2.should_receive(:add_tag).with('Name', :value => 'sub2')

        fake_aws_vpc.subnets.should_receive(:create).with('cider', {availability_zone: 'canada'}).and_return(sub1)
        fake_aws_vpc.subnets.should_receive(:create).with('cedar', {}).and_return(sub2)

        vpc.create_subnets({'sub1' => subnet_1_specs, 'sub2' => subnet_2_specs})
      end

    end

    describe 'deletion' do
      it 'can delete all subnets of a VPC' do
        fake_aws_vpc = double('ec2_vpc', subnets: [double('subnet')])

        fake_aws_vpc.subnets.each { |subnet| subnet.should_receive :delete }

        Bosh::Aws::VPC.new(double('ec2'), fake_aws_vpc).delete_subnets
      end
    end

    describe 'listing' do
      it "should produce an hash of the VPC's subnets' names and IDs" do
        fake_aws_vpc = double('aws_vpc')
        sub1 = double('subnet', id: 'sub-1')
        sub2 = double('subnet', id: 'sub-2')
        sub1.stub(:tags).and_return('Name' => 'name1')
        sub2.stub(:tags).and_return('Name' => 'name2')
        fake_aws_vpc.should_receive(:subnets).and_return([sub1, sub2])

        Bosh::Aws::VPC.new(double('ec2'), fake_aws_vpc).subnets.should == {'name1' => 'sub-1', 'name2' => 'sub-2'}
      end
    end

    describe 'NAT instances' do
      it 'should extract NAT instance specifications' do
        bosh_subnet = double('aws_subnet', tags: {'Name' => 'bosh'}, id: 'sub-123')
        cf_subnet = double('aws_subnet', tags: {'Name' => 'cf'}, id: 'sub-456')
        fake_aws_vpc = double('aws_vpc', subnets: [bosh_subnet, cf_subnet])

        subnet_specs = {
            'bosh' => {
                'nat_instance' => {
                    'name' => 'naim',
                    'foo' => 'bar'
                }
            },
            'cf' => {
                'nothing' => 21
            }
        }

        vpc = Bosh::Aws::VPC.new(double('ec2'), fake_aws_vpc)
        vpc.extract_nat_instance_specs(subnet_specs).should == [{'foo' => 'bar', 'subnet_id' => 'sub-123', 'name' => 'naim'}]
      end

      it 'should create NAT instances within the appropriate subnets' do
        bosh_subnet = double('aws_subnet', tags: {'Name' => 'bosh'}, id: 'sub-123')
        cf_subnet = double('aws_subnet', tags: {'Name' => 'cf'}, id: 'sub-456')
        cf2_subnet = double('aws_subnet', tags: {'Name' => 'cf2'}, id: 'sub-789')
        fake_ec2 = double(Bosh::Aws::EC2)
        fake_aws_vpc = double('aws_vpc', subnets: [bosh_subnet, cf_subnet, cf2_subnet])
        vpc = Bosh::Aws::VPC.new(fake_ec2, fake_aws_vpc)

        fake_ec2.should_receive(:create_nat_instance).with(
            'name' => 'naim',
            'subnet_id' => 'sub-123',
            'ip' => '1.2.3.4',
            'security_group' => 'so secure',
            'key_name' => 'keee',
            'instance_type' => 'm1.large'
        )
        fake_ec2.should_receive(:create_nat_instance).with(
            'name' => 'dunno',
            'subnet_id' => 'sub-789',
            'ip' => '4.5.6.7',
            'security_group' => 'group',
        )

        subnet_specs = {
            'bosh' => {
                'nat_instance' => {
                    'name' => 'naim',
                    'ip' => '1.2.3.4',
                    'security_group' => 'so secure',
                    'key_name' => 'keee',
                    'instance_type' => 'm1.large'
                }
            },
            'cf' => {
                'nothing' => 21
            },
            'cf2' => {
                'nat_instance' => {
                    'name' => 'dunno',
                    'ip' => '4.5.6.7',
                    'security_group' => 'group'
                }
            }
        }
        vpc.create_nat_instances(subnet_specs)
      end
    end
  end

  describe 'security groups' do
    describe 'creation' do
      let(:security_groups) { double('security_groups') }
      let(:security_group) { double('security_group') }

      it 'should be created with a single port' do
        security_groups.stub(:create).with('sg').and_return(security_group)
        security_groups.stub(:each)

        security_group.stub(:id)
        security_group.should_receive(:exists?).and_return(true)
        security_group.should_receive(:authorize_ingress).with(:tcp, 22, '1.2.3.0/24')
        security_group.should_receive(:authorize_ingress).with(:tcp, 23, '1.2.4.0/24')

        ingress_rules = [
            {'protocol' => :tcp, 'ports' => '22', 'sources' => '1.2.3.0/24'},
            {'protocol' => :tcp, 'ports' => '23', 'sources' => '1.2.4.0/24'}
        ]
        Bosh::Aws::VPC.new(double('ec2'), double('aws_vpc', security_groups: security_groups)).
            create_security_groups ['name' => 'sg', 'ingress' => ingress_rules]
      end

      it 'should be created with a port range' do
        security_groups.stub(:create).with('sg').and_return(security_group)
        security_groups.stub(:each)

        security_group.stub(:id)
        security_group.should_receive(:exists?).and_return(true)
        security_group.should_receive(:authorize_ingress).with(:tcp, 5..60, '1.2.3.0/24')

        ingress_rules = [
            {'protocol' => :tcp, 'ports' => '5 - 60', 'sources' => '1.2.3.0/24'}
        ]
        Bosh::Aws::VPC.new(double('ec2'), double('aws_vpc', security_groups: security_groups)).
            create_security_groups ['name' => 'sg', 'ingress' => ingress_rules]
      end

      it 'should delete unused existing security group on create' do
        existing_security_group = double('security_group', name: 'sg')

        security_group.stub(:authorize_ingress).with(:tcp, 22, '1.2.3.0/24')
        security_groups.stub(:create).with('sg').and_return(security_group)
        security_groups.stub(:each).and_yield(existing_security_group)
        security_group.stub(:id)
        security_group.should_receive(:exists?).and_return(true)

        existing_security_group.should_receive :delete

        ingress_rules = [
            {'protocol' => :tcp, 'ports' => 22, 'sources' => '1.2.3.0/24'}
        ]
        Bosh::Aws::VPC.new(double('ec2'), double('aws_vpc', security_groups: security_groups)).
            create_security_groups ['name' => 'sg', 'ingress' => ingress_rules]
      end

      it 'should not delete existing security group if in use' do
        existing_security_group = double('security_group', name: 'sg')

        security_groups.stub(:each).and_yield(existing_security_group)
        existing_security_group.stub(:delete).and_raise(::AWS::EC2::Errors::DependencyViolation)

        security_groups.should_not_receive(:create)

        ingress_rules = [
            {'protocol' => :tcp, 'ports' => 22, 'sources' => '1.2.3.0/24'}
        ]
        Bosh::Aws::VPC.new(double('ec2'), double('aws_vpc', security_groups: security_groups)).
            create_security_groups ['name' => 'sg', 'ingress' => ingress_rules]
      end
    end

    describe 'deletion' do
      it 'can delete all security groups of a vpc except the default one' do
        fake_default_group = double('security_group', name: 'default')
        fake_special_group = double('security_group', name: 'special')

        fake_special_group.should_receive :delete
        fake_default_group.should_not_receive :delete

        Bosh::Aws::VPC.new(double('ec2'), double('aws_vpc', security_groups: [fake_default_group, fake_special_group])).
            delete_security_groups
      end
    end

    describe 'finding' do
      it 'can find security groups by name' do
        security_group1 = double('sg1', name: 'sg_name_1', id: 'sg_id_1')
        security_group2 = double('sg2', name: 'sg_name_2', id: 'sg_id_2')
        vpc = Bosh::Aws::VPC.new(double('ec2'), double('aws_vpc', security_groups: [security_group1, security_group2]))

        vpc.security_group_by_name('sg_name_2').should == security_group2
      end
    end
  end

  describe 'route tables' do
    describe 'creating for subnets' do
      context 'when the default route is an Internet gateway' do
        it 'the route table for the given subnet should have the given internet gateway as the default route' do
          fake_ec2 = double(Bosh::Aws::EC2)
          fake_aws_internet_gateway = double(AWS::EC2::InternetGateway)
          fake_aws_subnet = double(AWS::EC2::Subnet)
          fake_aws_route_table = double(AWS::EC2::RouteTable)
          fake_aws_route_table_collection = double(AWS::EC2::RouteTableCollection, create: fake_aws_route_table)
          fake_aws_vpc = double(
              AWS::EC2::VPC,
              route_tables: fake_aws_route_table_collection,
              internet_gateway: fake_aws_internet_gateway
          )

          fake_aws_subnet.should_receive(:route_table=).with(fake_aws_route_table)
          fake_aws_route_table.should_receive(:create_route).with('0.0.0.0/0', internet_gateway: fake_aws_internet_gateway)

          vpc = Bosh::Aws::VPC.new(fake_ec2, fake_aws_vpc)
          vpc.make_internet_gateway_default_route_for_subnet(fake_aws_subnet)
        end
      end

      context 'when the default route is an instance' do
        it 'the route table for the given subnet should have the given instance as its default route' do
          fake_ec2 = double(Bosh::Aws::EC2)
          fake_aws_subnet = double(AWS::EC2::Subnet)
          fake_aws_route_table = double(AWS::EC2::RouteTable)
          fake_aws_nat_instance = double(AWS::EC2::Instance)
          fake_aws_route_table_collection = double(AWS::EC2::RouteTableCollection, create: fake_aws_route_table)
          fake_aws_vpc = double(
              AWS::EC2::VPC,
              route_tables: fake_aws_route_table_collection
          )

          fake_aws_subnet.should_receive(:route_table=).with(fake_aws_route_table)
          fake_aws_route_table.should_receive(:create_route).with('0.0.0.0/0', instance: fake_aws_nat_instance)

          vpc = Bosh::Aws::VPC.new(fake_ec2, fake_aws_vpc)
          vpc.make_nat_instance_default_route_for_subnet(fake_aws_subnet, fake_aws_nat_instance)
        end
      end
    end

    describe 'deletion' do
      it 'should delete all route tables except the main one' do
        fake_ec2 = double(Bosh::Aws::EC2)
        fake_main_aws_route_table = double(AWS::EC2::RouteTable, main?: true)
        fake_secondary_aws_route_table = double(AWS::EC2::RouteTable, main?: false)
        fake_aws_vpc = double(
            AWS::EC2::VPC,
            route_tables: [fake_main_aws_route_table, fake_secondary_aws_route_table]
        )

        fake_main_aws_route_table.should_not_receive(:delete)
        fake_secondary_aws_route_table.should_receive(:delete)

        vpc = Bosh::Aws::VPC.new(fake_ec2, fake_aws_vpc)
        vpc.delete_route_tables
      end
    end
  end

  describe 'dhcp_options' do
    describe 'creation' do
      it 'can create DHCP options' do
        fake_dhcp_option_collection = double('dhcp options collection')
        fake_dhcp_options = double('dhcp options')

        fake_dhcp_option_collection.should_receive(:create).with({}).and_return(fake_dhcp_options)
        fake_dhcp_options.should_receive(:associate).with('vpc-xxxxxxxx')

        Bosh::Aws::VPC.new(
            double('ec2', dhcp_options: fake_dhcp_option_collection),
            double('aws_vpc', id: 'vpc-xxxxxxxx', dhcp_options: double('default dhcp options').as_null_object)
        ).create_dhcp_options({})
      end

      it 'can delete the default DHCP options' do
        fake_dhcp_option_collection = double('dhcp options collection')
        fake_default_dhcp_options = double('default dhcp options')

        fake_dhcp_option_collection.stub(:create).and_return(double('dhcp options').as_null_object)

        fake_default_dhcp_options.should_receive :delete

        Bosh::Aws::VPC.new(
            double('ec2', dhcp_options: fake_dhcp_option_collection),
            double('aws_vpc', id: 'vpc-xxxxxxxx', dhcp_options: fake_default_dhcp_options)
        ).create_dhcp_options({})
      end
    end
  end

  describe 'state' do
    it 'should return the underlying state' do
      fake_aws_vpc = double('aws_vpc')
      fake_aws_vpc.should_receive(:state).and_return('a cool state')

      Bosh::Aws::VPC.new(double('ec2'), fake_aws_vpc).state.should == 'a cool state'
    end
  end

  describe 'attaching internet gateways' do
    it 'should attach to a VPC by gateway ID' do
      fake_aws_vpc = double('aws_vpc')
      fake_aws_vpc.should_receive(:internet_gateway=).with('gw1id')
      Bosh::Aws::VPC.new(double('ec2'), fake_aws_vpc).attach_internet_gateway('gw1id')
    end
  end
end
