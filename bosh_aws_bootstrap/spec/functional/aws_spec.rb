require 'spec_helper'

describe Bosh::Cli::Command::AWS do
  let(:aws) { subject }
  let(:default_config_filename) do
    File.expand_path(File.join(
                         File.dirname(__FILE__), "..", "..", "templates", "aws_configuration_template.yml.erb"
                     ))
  end
  before { aws.stub(:sleep) }

  describe "command line tools" do
    describe "aws bootstrap micro" do
      around do |example|
        Dir.mktmpdir do |dirname|
          Dir.chdir dirname do
            FileUtils.cp(File.join(File.dirname(__FILE__), "..", "assets", "test-output.yml"), "aws_vpc_receipt.yml")
            FileUtils.cp(File.join(File.dirname(__FILE__), "..", "assets", "test-aws_route53_receipt.yml"), "aws_route53_receipt.yml")
            example.run
          end
        end
      end

      before do
        Bosh::Cli::Command::Micro.any_instance.stub(:micro_deployment)
        Bosh::Cli::Command::Micro.any_instance.stub(:perform)
        Bosh::Cli::Command::User.any_instance.stub(:create)
        Bosh::Cli::Command::Misc.any_instance.stub(:login)
        aws.stub(:micro_ami).and_return("ami-123456")
      end

      it "should generate a microbosh.yml in the right location" do
        ::Bosh::Cli::Command::Base.any_instance.stub(:non_interactive?).and_return(true)
        File.exist?("deployments/micro/micro_bosh.yml").should == false
        aws.bootstrap_micro
        File.exist?("deployments/micro/micro_bosh.yml").should == true
      end

      it "should remove any existing deployment artifacts first" do
        ::Bosh::Cli::Command::Base.any_instance.stub(:non_interactive?).and_return(true)
        FileUtils.mkdir_p("deployments/micro")
        File.open("deployments/leftover.yml", "w") { |f| f.write("old stuff!") }
        File.open("deployments/micro/leftover.yml", "w") { |f| f.write("old stuff!") }
        File.exist?("deployments/leftover.yml").should == true
        File.exist?("deployments/micro/leftover.yml").should == true
        aws.bootstrap_micro
        File.exist?("deployments/leftover.yml").should == false
        File.exist?("deployments/micro/leftover.yml").should == false
      end

      it "should deploy a micro bosh" do
        ::Bosh::Cli::Command::Base.any_instance.stub(:non_interactive?).and_return(true)
        Bosh::Cli::Command::Micro.any_instance.should_receive(:micro_deployment).with("micro")
        Bosh::Cli::Command::Micro.any_instance.should_receive(:perform).with("ami-123456")
        aws.bootstrap_micro
      end

      it "should login with admin/admin with non-interactive mode" do
        ::Bosh::Cli::Command::Base.any_instance.stub(:non_interactive?).and_return(true)
        Bosh::Cli::Command::Misc.any_instance.should_receive(:login).with("admin", "admin")
        aws.bootstrap_micro
      end

      it "should login with created user with interactive mode" do
        Bosh::Cli::Command::User.any_instance.should_receive(:create).with("foo", "foo")
        Bosh::Cli::Command::Misc.any_instance.should_receive(:login).with("foo", "foo")
        aws.stub(:ask).and_return("foo")
        aws.bootstrap_micro
      end
    end

    describe "aws generate micro_bosh" do
      let(:create_vpc_output_yml) { asset "test-output.yml" }
      let(:route53_receipt_yml) { asset "test-aws_route53_receipt.yml" }

      around do |test|
        Dir.mktmpdir do |dir|
          Dir.chdir(dir) do
            aws.create_micro_bosh_manifest(create_vpc_output_yml, route53_receipt_yml)
            test.run
          end
        end
      end

      it "uses some of the normal director keys" do
        @micro_bosh_yaml = YAML.load_file("micro_bosh.yml")

        @micro_bosh_yaml['name'].should == "micro-dev102"
        @micro_bosh_yaml['network']['vip'].should == "50.200.100.1"
        @micro_bosh_yaml['network']['cloud_properties']['subnet'].should == "subnet-4bdf6c26"
        @micro_bosh_yaml['resources']['cloud_properties']['availability_zone'].should == "us-east-1a"

        @micro_bosh_yaml['cloud']['properties']['aws']['access_key_id'].should == "..."
        @micro_bosh_yaml['cloud']['properties']['aws']['secret_access_key'].should == "..."
        @micro_bosh_yaml['cloud']['properties']['aws']['region'].should == "us-east-1"
      end
    end

    describe "aws generate bosh" do
      let(:create_vpc_output_yml) { asset "test-output.yml" }
      let(:route53_receipt_yml) { asset "test-aws_route53_receipt.yml" }

      it "generates required bosh deployment keys" do
        Dir.mktmpdir do |dir|
          Dir.chdir(dir) do
            aws.stub(:target_required)
            aws.stub_chain(:director, :uuid).and_return("deadbeef")
            aws.create_bosh_manifest(create_vpc_output_yml, route53_receipt_yml)
            YAML.load_file("bosh.yml")['name'].should == "vpc-bosh-dev102"
          end
        end
      end
    end

    describe "aws create" do
      let(:config_file) { asset "create_all.yml" }

      def stub_required_environment_variables
        ENV.stub(:[]).with(anything()).and_call_original
        ENV.stub(:[]).with("BOSH_AWS_SECRET_ACCESS_KEY").and_return('fake secret access key')
        ENV.stub(:[]).with("BOSH_AWS_ACCESS_KEY_ID").and_return('fake access key id')
        ENV.stub(:[]).with("BOSH_VPC_SUBDOMAIN").and_return('fake vpc subdomain')
      end

      it "should create the specified VPCs, RDS DBs, and S3 Volumes" do
        aws.should_receive(:create_key_pairs).with(config_file)
        aws.should_receive(:create_vpc).with(config_file)
        aws.should_receive(:create_route53_records).with(config_file)
        aws.should_receive(:create_rds_dbs).with(config_file)
        aws.should_receive(:create_s3).with(config_file)
        aws.create config_file
      end

      it "should default the configuration file when not passed in" do
        stub_required_environment_variables
        File.exist?(default_config_filename).should == true
        aws.should_receive(:create_key_pairs).with(default_config_filename)
        aws.should_receive(:create_vpc).with(default_config_filename)
        aws.should_receive(:create_route53_records).with(default_config_filename)
        aws.should_receive(:create_rds_dbs).with(default_config_filename)
        aws.should_receive(:create_s3).with(default_config_filename)
        aws.create
      end
    end

    describe "aws destroy" do
      let(:config_file) { asset "config.yml" }

      it "should destroy the specified VPCs, RDS DBs, and S3 Volumes" do
        aws.should_receive(:delete_all_ec2).with(config_file)
        aws.should_receive(:delete_all_ebs).with(config_file)
        aws.should_receive(:delete_all_rds_dbs).with(config_file)
        aws.should_receive(:delete_all_s3).with(config_file)
        aws.should_receive(:delete_all_vpcs).with(config_file)
        aws.should_receive(:delete_all_security_groups).with(config_file)
        aws.should_receive(:delete_all_route53_records).with(config_file)
        aws.should_receive(:delete_all_elbs).with(config_file)
        aws.destroy config_file
      end

      it "should use a default config file when none is provided" do
        aws.should_receive(:delete_all_ec2).with(default_config_filename)
        aws.should_receive(:delete_all_ebs).with(default_config_filename)
        aws.should_receive(:delete_all_rds_dbs).with(default_config_filename)
        aws.should_receive(:delete_all_s3).with(default_config_filename)
        aws.should_receive(:delete_all_vpcs).with(default_config_filename)
        aws.should_receive(:delete_all_security_groups).with(default_config_filename)
        aws.should_receive(:delete_all_route53_records).with(default_config_filename)
        aws.should_receive(:delete_all_elbs).with(default_config_filename)
        aws.destroy
      end
    end

    describe "aws delete_all security_groups" do
      let(:config_file) { asset "config.yml" }

      it "should retry if it can not delete security groups due to eventual consistency" do
        fake_ec2 = mock("ec2")
        Bosh::Aws::EC2.stub(:new).and_return(fake_ec2)
        aws.stub(aws_retry_wait_time: 0)
        fake_ec2.should_receive(:delete_all_security_groups).ordered.exactly(119).times.and_raise(::AWS::EC2::Errors::InvalidGroup::InUse)
        fake_ec2.should_receive(:delete_all_security_groups).ordered.once.and_return(true)
        aws.delete_all_security_groups(config_file)
      end
    end

    describe "aws create vpc" do
      let(:config_file) { asset "config.yml" }

      def make_fake_vpc!(overrides = {})
        fake_ec2 = mock("ec2")
        fake_vpc = mock("vpc")
        fake_elb = mock("elb")
        fake_route53 = mock("route53")
        fake_igw = mock(AWS::EC2::InternetGateway, id: "id2")

        Bosh::Aws::EC2.stub(:new).and_return(fake_ec2)
        Bosh::Aws::VPC.stub(:create).and_return(fake_vpc)
        Bosh::Aws::Route53.stub(:new).and_return(fake_route53)
        Bosh::Aws::ELB.stub(:new).and_return(fake_elb)

        fake_vpc.stub(:vpc_id).and_return("vpc id")
        fake_vpc.stub(:create_dhcp_options)
        fake_vpc.stub(:create_security_groups)
        fake_vpc.stub(:create_subnets)
        fake_vpc.stub(:create_nat_instances)
        fake_vpc.stub(:setup_subnet_routes)
        fake_vpc.stub(:subnets).and_return({'bosh' => "amz-subnet1", 'name2' => "amz-subnet2"})
        fake_vpc.stub(:attach_internet_gateway)
        fake_ec2.stub(:allocate_elastic_ips)
        fake_ec2.stub(:force_add_key_pair)
        fake_ec2.stub(:create_internet_gateway).and_return(fake_igw)
        fake_ec2.stub(:elastic_ips).and_return(["1.2.3.4", "5.6.7.8"])
        fake_elb.stub(:create).and_return(mock("new elb", dns_name: 'elb-123.example.com'))
        fake_route53.stub(:create_zone)
        fake_route53.stub(:add_record)
        fake_vpc
      end

      pending "should create all the components of a VPC"

      it "should flush the output to a YAML file" do
        fake_vpc = make_fake_vpc!
        fake_vpc.stub(:state).and_return(:available)

        aws.should_receive(:flush_output_state) do |args|
          args.should match(/aws_vpc_receipt.yml/)
        end

        aws.create_vpc config_file

        aws.output_state["vpc"]["id"].should == "vpc id"
        aws.output_state["vpc"]["subnets"].should == {"bosh" => "amz-subnet1", "name2" => "amz-subnet2"}
        aws.output_state["original_configuration"].should == YAML.load_file(config_file)
      end

      context "when the VPC is not immediately available" do
        it "should try several times and continue when available" do
          fake_vpc = make_fake_vpc!
          fake_vpc.should_receive(:state).exactly(3).times.and_return(:pending, :pending, :available)
          aws.create_vpc config_file
        end

        it "should fail after 60 attempts when not available" do
          fake_vpc = make_fake_vpc!
          fake_vpc.stub(:state).and_return(:pending)
          expect { aws.create_vpc config_file }.to raise_error
        end
      end

      context "when a step in the creation fails" do
        it "should still flush the output to a YAML so the user knows what resources were provisioned" do
          fake_vpc = mock("vpc")

          Bosh::Aws::EC2.stub(:new)
          Bosh::Aws::VPC.stub(:create).and_return(fake_vpc)
          fake_vpc.stub(:vpc_id).and_return("vpc id")
          fake_vpc.stub(:create_subnets).and_raise

          aws.should_receive(:flush_output_state) do |args|
            args.should match(/create-vpc-output-\d{14}.yml/)
          end

          expect { aws.create_vpc config_file }.to raise_error

          aws.output_state["vpc"]["id"].should == "vpc id"
        end
      end
    end

    describe "aws destroy vpc" do
      let(:output_file) { asset "test-output.yml" }

      it "should delete the vpc and all its dependencies, and release the elastic ips" do
        fake_ec2 = mock("ec2")
        fake_vpc = mock("vpc")
        fake_dhcp_options = mock("dhcp options")
        fake_route53 = mock("route53")

        Bosh::Aws::EC2.stub(:new).and_return(fake_ec2)
        Bosh::Aws::VPC.stub(:find).with(fake_ec2, "vpc-13724979").and_return(fake_vpc)
        Bosh::Aws::Route53.stub(:new).and_return(fake_route53)

        fake_vpc.stub(:dhcp_options).and_return(fake_dhcp_options)
        fake_vpc.stub(:instances_count).and_return(0)

        fake_vpc.should_receive :delete_security_groups
        fake_vpc.should_receive :delete_subnets
        fake_vpc.should_receive :delete_vpc
        fake_dhcp_options.should_receive :delete
        fake_ec2.should_receive(:internet_gateway_ids).and_return(["gw1id", "gw2id"])
        fake_ec2.should_receive(:delete_internet_gateways).with(["gw1id", "gw2id"])
        fake_ec2.should_receive(:remove_key_pair).with "somenamez"
        fake_ec2.should_receive(:release_elastic_ips).with ["107.23.46.162", "107.23.53.76"]
        fake_ec2.should_receive(:release_elastic_ips).with ["123.45.6.7"]
        fake_ec2.should_receive(:release_elastic_ips).with ["123.45.6.8"]
        fake_ec2.should_receive(:release_elastic_ips).with ["123.4.5.9"]
        fake_route53.should_receive(:delete_record).with("*", "cfdev.com")
        fake_route53.should_receive(:delete_record).with("micro", "cfdev.com")
        fake_route53.should_receive(:delete_record).with("bosh", "cfdev.com")
        fake_route53.should_receive(:delete_record).with("bat", "cfdev.com")

        aws.delete_vpc output_file
      end

      it "should retry on AWS errors" do
        fake_ec2 = mock("ec2")
        fake_vpc = mock("vpc")
        fake_route_53 = mock("route53")
        fake_dhcp_options = mock("dhcp_options")

        Bosh::Aws::EC2.stub(:new).and_return(fake_ec2)
        Bosh::Aws::VPC.stub(:find).and_return(fake_vpc)
        Bosh::Aws::Route53.stub(:new).and_return(fake_vpc)

        fake_vpc.stub(:instances_count).and_return(0)
        fake_vpc.stub(:dhcp_options).and_return(fake_dhcp_options)
        fake_vpc.stub(:delete_security_groups)
        fake_vpc.stub(:delete_subnets)
        fake_vpc.stub(:delete_vpc)
        fake_vpc.stub(:remove_key_pair)
        fake_vpc.stub(:delete_record)

        fake_ec2.stub(:internet_gateway_ids)
        fake_ec2.stub(:delete_internet_gateways)
        fake_ec2.stub(:remove_key_pair)
        fake_ec2.stub(:release_elastic_ips)

        fake_dhcp_options.stub(:delete)

        aws.stub(aws_retry_wait_time: 0)

        fake_vpc.should_receive(:delete_security_groups).ordered.exactly(119).times.and_raise(::AWS::EC2::Errors::InvalidGroup::InUse)
        fake_vpc.should_receive(:delete_security_groups).ordered.once.and_return(true)
        aws.delete_vpc output_file
      end

      context "when there are instances running" do
        it "throws a nice error message and doesn't delete any resources" do
          fake_vpc = mock("vpc")

          Bosh::Aws::EC2.stub(:new)
          Bosh::Aws::VPC.stub(:find).and_return(fake_vpc)

          fake_vpc.stub(:instances_count).and_return(1)
          fake_vpc.stub(:vpc_id).and_return("vpc-13724979")

          expect {
            fake_vpc.should_not_receive(:delete_security_groups)
            aws.delete_vpc output_file
          }.to raise_error(Bosh::Cli::CliError, "1 instance(s) running in vpc-13724979 - delete them first")
        end
      end
    end

    describe "aws create s3" do
      let(:config_file) { asset "config.yml" }
      let(:fake_s3) { mock("s3") }

      it "should create all configured buckets" do

        Bosh::Aws::S3.stub(:new).and_return(fake_s3)

        fake_s3.should_receive(:create_bucket).with("b1").ordered
        fake_s3.should_receive(:create_bucket).with("b2").ordered

        aws.create_s3(config_file)
      end

      it "should do nothing if s3 config is empty" do
        aws.stub(:load_yaml_file).and_return({})

        aws.should_receive(:say).with("s3 not set in config.  Skipping")
        fake_s3.should_not_receive(:create_bucket)

        aws.create_s3(config_file)
      end
    end

    describe "aws empty s3" do
      let(:config_file) { asset "config.yml" }

      it "should warn the user that the operation is destructive and list the buckets" do
        fake_ec2 = mock("ec2")
        Bosh::Aws::EC2.stub(:new).and_return(fake_ec2)
        fake_ec2.stub(:instances_count).and_return(20)
        fake_s3 = mock("s3")

        Bosh::Aws::S3.stub(:new).and_return(fake_s3)
        fake_s3.stub(:bucket_names).and_return(["buckets of fun", "barrel of monkeys"])

        aws.should_receive(:say).with("THIS IS A VERY DESTRUCTIVE OPERATION AND IT CANNOT BE UNDONE!\n".red)
        aws.should_receive(:say).with("Buckets:\n\tbuckets of fun\n\tbarrel of monkeys")
        aws.should_receive(:confirmed?).with("Are you sure you want to empty and delete all buckets?").and_return(false)

        aws.delete_all_s3 config_file
      end

      it "should not empty S3 if more than 20 insances are running" do
        fake_ec2 = mock("ec2")
        Bosh::Aws::EC2.stub(:new).and_return(fake_ec2)
        fake_ec2.stub(:instances_count).and_return(21)

        expect {
          aws.delete_all_s3 config_file
        }.to raise_error(Bosh::Cli::CliError, "21 instance(s) running.  This isn't a dev account (more than 20) please make sure you want to do this, aborting.")
      end

      context "interactive mode (default)" do
        context "when the users agrees to nuke the buckets" do
          it "should empty and delete all S3 buckets associated with an account" do
            fake_ec2 = mock("ec2")
            Bosh::Aws::EC2.stub(:new).and_return(fake_ec2)
            fake_ec2.stub(:instances_count).and_return(20)
            fake_s3 = mock("s3")
            fake_bucket_names = %w[foo bar]

            Bosh::Aws::S3.stub(:new).and_return(fake_s3)
            fake_s3.stub(:bucket_names).and_return(fake_bucket_names)

            aws.stub(:say).twice
            aws.stub(:confirmed?).and_return(true)

            fake_s3.should_receive :empty

            aws.delete_all_s3 config_file
          end
        end

        context "when the user wants to bail out" do
          it "should not destroy the buckets" do
            fake_ec2 = mock("ec2")
            Bosh::Aws::EC2.stub(:new).and_return(fake_ec2)
            fake_ec2.stub(:instances_count).and_return(20)
            fake_s3 = mock("s3")

            Bosh::Aws::S3.stub(:new).and_return(fake_s3)
            fake_s3.stub(:bucket_names).and_return(double.as_null_object)
            aws.stub(:say).twice
            aws.stub(:confirmed?).and_return(false)

            fake_s3.should_not_receive :empty

            aws.delete_all_s3 config_file
          end
        end
      end

      context "non-interactive mode" do
        it "should empty and delete all S3 buckets associated with an account" do
          fake_ec2 = mock("ec2")
          Bosh::Aws::EC2.stub(:new).and_return(fake_ec2)
          fake_ec2.stub(:instances_count).and_return(20)
          fake_s3 = mock("s3")

          Bosh::Aws::S3.stub(:new).and_return(fake_s3)
          fake_s3.stub(:bucket_names).and_return(%w[foo bar])
          aws.stub(:say).twice

          fake_s3.should_receive :empty

          ::Bosh::Cli::Command::Base.any_instance.stub(:non_interactive?).and_return(true)
          aws.delete_all_s3 config_file
        end
      end
    end

    describe "aws create route53 records" do
      pending "should create the required instances and associate Elastic IPs"

      pending "should create DNS records for the appropriate instances"
    end

    describe "aws delete_all route53 records" do
      pending "should delete all route53 records except NS and SOA"

      pending "can optionally omit deletion of other record types"
    end

    describe "aws terminate_all ec2" do
      let(:config_file) { asset "config.yml" }

      it "should warn the user that the operation is destructive and list the instances" do
        fake_ec2 = mock("ec2")

        Bosh::Aws::EC2.stub(:new).and_return(fake_ec2)
        fake_ec2.stub(:instances_count).and_return(2)
        fake_ec2.stub(:instance_names).and_return({"I12345" => "instance_1", "I67890" => "instance_2"})

        aws.should_receive(:say).with("THIS IS A VERY DESTRUCTIVE OPERATION AND IT CANNOT BE UNDONE!\n".red)
        aws.should_receive(:say).with("Instances:\n\tinstance_1 (id: I12345)\n\tinstance_2 (id: I67890)")
        aws.should_receive(:confirmed?).
            with("Are you sure you want to terminate all terminatable EC2 instances and their associated non-persistent EBS volumes?").
            and_return(false)

        aws.delete_all_ec2 config_file
      end

      it "should error if more than 20 instances are running" do
        fake_ec2 = mock("ec2")
        Bosh::Aws::EC2.stub(:new).and_return(fake_ec2)
        fake_ec2.stub(:instances_count).and_return(21)

        expect {
          aws.delete_all_ec2 config_file
        }.to raise_error(Bosh::Cli::CliError, "21 instance(s) running.  This isn't a dev account (more than 20) please make sure you want to do this, aborting.")
      end

      context "interactive mode (default)" do
        context 'when the user agrees to terminate all the instances' do
          it 'should terminate all instances' do
            fake_ec2 = mock("ec2")

            Bosh::Aws::EC2.stub(:new).and_return(fake_ec2)
            aws.stub(:say)
            aws.stub(:confirmed?).and_return(true)
            fake_ec2.stub(:instances_count).and_return(2)
            fake_ec2.stub(:instance_names).and_return(%w[i-foo i-bar])

            fake_ec2.should_receive :terminate_instances

            aws.delete_all_ec2(config_file)
          end
        end

        context 'when the user wants to bail out of ec2 termination' do
          it 'should not terminate any instances' do
            fake_ec2 = mock("ec2")

            Bosh::Aws::EC2.stub(:new).and_return(fake_ec2)
            aws.stub(:say).twice
            aws.stub(:confirmed?).and_return(false)
            fake_ec2.stub(:instances_count).and_return(0)
            fake_ec2.stub(:instance_names).and_return(double.as_null_object)

            fake_ec2.should_not_receive :terminate_instances

            aws.delete_all_ec2 config_file
          end
        end
      end

      context "non-interactive mode" do
        it 'should terminate all instances' do
          fake_ec2 = mock("ec2")

          Bosh::Aws::EC2.stub(:new).and_return(fake_ec2)
          aws.stub(:say)
          fake_ec2.stub(:instances_count).and_return(0)
          fake_ec2.stub_chain(:instance_names, :map).and_return(["foo (id: i-1234)"])

          fake_ec2.should_receive :terminate_instances

          ::Bosh::Cli::Command::Base.any_instance.stub(:non_interactive?).and_return(true)
          aws.delete_all_ec2(config_file)
        end
      end
    end

    describe "aws delete_all ebs" do
      let(:config_file) { asset "config.yml" }

      it "should warn the user that the operation is destructive and list number of volumes to be deleted" do
        fake_ec2 = mock("ec2")

        Bosh::Aws::EC2.stub(:new).and_return(fake_ec2)
        fake_ec2.stub(:volume_count).and_return(2)

        aws.should_receive(:say).with("THIS IS A VERY DESTRUCTIVE OPERATION AND IT CANNOT BE UNDONE!\n".red)
        aws.should_receive(:say).with("It will delete 2 EBS volume(s)")
        aws.should_receive(:confirmed?).
            with("Are you sure you want to delete all unattached EBS volumes?").
            and_return(false)

        aws.delete_all_ebs config_file
      end

      it "should error if more than 20 volumes are present" do
        fake_ec2 = mock("ec2")
        Bosh::Aws::EC2.stub(:new).and_return(fake_ec2)
        fake_ec2.stub(:volume_count).and_return(21)

        expect {
          aws.delete_all_ebs config_file
        }.to raise_error(Bosh::Cli::CliError, "21 volume(s) present.  This isn't a dev account (more than 20) please make sure you want to do this, aborting.")
      end

      context "interactive mode (default)" do
        context 'when the user agrees to terminate all the instances' do
          it 'should terminate all instances' do
            fake_ec2 = mock("ec2")

            Bosh::Aws::EC2.stub(:new).and_return(fake_ec2)
            aws.stub(:say)
            aws.stub(:confirmed?).and_return(true)
            fake_ec2.stub(:volume_count).and_return(1)

            fake_ec2.should_receive :delete_volumes

            aws.delete_all_ebs(config_file)
          end
        end

        context 'when the user wants to bail out of ec2 termination' do
          it 'should not terminate any instances' do
            fake_ec2 = mock("ec2")

            Bosh::Aws::EC2.stub(:new).and_return(fake_ec2)
            aws.stub(:say)
            aws.stub(:confirmed?).and_return(false)
            fake_ec2.stub(:volume_count).and_return(0)

            fake_ec2.should_not_receive :delete_volumes

            aws.delete_all_ebs config_file
          end
        end
      end

      context "non-interactive mode" do
        it 'should terminate all instances' do
          fake_ec2 = mock("ec2")

          Bosh::Aws::EC2.stub(:new).and_return(fake_ec2)
          aws.stub(:say)
          fake_ec2.stub(:volume_count).and_return(1)

          fake_ec2.should_receive :delete_volumes

          ::Bosh::Cli::Command::Base.any_instance.stub(:non_interactive?).and_return(true)
          aws.delete_all_ebs(config_file)
        end
      end
    end

    describe "aws snapshot director deployments" do
      let(:config_file) { asset "config.yml" }

      it "should snapshot EBS volumes in all deployments" do
        bat_vm_fixtures = [
            {"agent_id" => "a1b2", "cid" => "i-a1b2c3", "job" => "director", "index" => 0},
            {"agent_id" => "a3b4", "cid" => "i-d4e5f6", "job" => "postgres", "index" => 0}
        ]
        bosh_vm_fixtures = [
            {"agent_id" => "a1b2", "cid" => "i-g1h2i3", "job" => "director", "index" => 0}
        ]

        fake_director = mock("director", :uuid => "dir-uuid")
        fake_ec2 = mock("ec2")
        fake_instance_collection = mock("instance_collection")
        fake_instance = mock("instance", :exists? => true)

        fake_attachment = mock("attachment")

        # Inherited from Bosh::Cli::Command::Base
        aws.stub(
            auth_required: true,
            director: fake_director,
            target: "http://1.2.3.4:56789",
            target_url: "http://1.2.3.4:56789",
            target_name: "http://1.2.3.4:56789"
        )

        Bosh::Aws::EC2.stub(:new).and_return(fake_ec2)
        AWS::EC2::InstanceCollection.stub(:new).and_return(fake_instance_collection)
        fake_ec2.should_receive(:snapshot_volume).exactly(4).times

        aws.should_receive(:say).with("Creating snapshots for director `http://1.2.3.4:56789'")
        fake_director.should_receive(:list_deployments).and_return([{"name" => "bat"}, {"name" => "bosh"}])

        aws.should_receive(:say).with("  deployment: `bat'")
        fake_director.should_receive(:list_vms).with("bat").and_return(bat_vm_fixtures)
        fake_ec2.should_receive(:instances_for_ids).with(["i-a1b2c3", "i-d4e5f6"]).and_return(fake_instance_collection)
        fake_instance_collection.should_receive(:[]).twice.times.and_return(fake_instance)

        aws.should_receive(:say).with("    instance: `i-a1b2c3'")
        fake_instance.should_receive(:block_device_mappings).
            and_return({"/dev/sda" => fake_attachment, "/dev/sdb" => fake_attachment})
        aws.should_receive(:say).with("      volume: `v-a1b2c3' device: `/dev/sda'")
        fake_attachment.should_receive(:volume).twice.and_return(mock_volume("v-a1b2c3"))
        aws.should_receive(:say).with("      volume: `v-a4b5c6' device: `/dev/sdb'")
        fake_attachment.should_receive(:volume).twice.and_return(mock_volume("v-a4b5c6"))

        aws.should_receive(:say).with("    instance: `i-d4e5f6'")
        fake_instance.should_receive(:block_device_mappings).and_return({"/dev/sdc" => fake_attachment})
        aws.should_receive(:say).with("      volume: `v-d4e5f6' device: `/dev/sdc'")
        fake_attachment.should_receive(:volume).twice.and_return(mock_volume("v-d4e5f6"))

        aws.should_receive(:say).with("  deployment: `bosh'")
        fake_director.should_receive(:list_vms).with("bosh").and_return(bosh_vm_fixtures)
        fake_ec2.should_receive(:instances_for_ids).with(["i-g1h2i3"]).and_return(fake_instance_collection)
        fake_instance_collection.should_receive(:[]).and_return(fake_instance)

        aws.should_receive(:say).with("    instance: `i-g1h2i3'")
        fake_instance.should_receive(:block_device_mappings).and_return({"/dev/sdd" => fake_attachment})
        aws.should_receive(:say).with("      volume: `v-g1h2i3' device: `/dev/sdd'")
        fake_attachment.should_receive(:volume).twice.and_return(mock_volume("v-g1h2i3"))

        aws.snapshot_deployments(config_file)
      end
    end

    describe "aws create rds databases" do
      let(:config_file) { asset "config.yml" }
      let(:receipt_file) { asset "test-output.yml" }

      def make_fake_rds!(opts = {})
        retries_needed = opts[:retries_needed] || 0
        creation_options = opts[:aws_creation_options]
        fake_rds = double(Bosh::Aws::RDS)
        Bosh::Aws::RDS.stub(:new).and_return(fake_rds)

        fake_rds.should_receive(:database_exists?).with("ccdb").and_return(false)

        create_database_params = ["ccdb", ["subnet-xxxxxxx1", "subnet-xxxxxxx2"], "vpc-13724979"]
        create_database_params << creation_options if creation_options
        fake_rds.should_receive(:create_database).with(*create_database_params).and_return(
            :engine => "mysql",
            :master_username => "ccdb_user",
            :master_user_password => "ccdb_password"
        )

        fake_rds.should_receive(:database_exists?).with("uaadb").and_return(false)
        fake_rds.should_receive(:create_database).
            with("uaadb", ["subnet-xxxxxxx1", "subnet-xxxxxxx2"], "vpc-13724979").and_return(
            :engine => "mysql",
            :master_username => "uaa_user",
            :master_user_password => "uaa_password")

        fake_ccdb_rds = mock("ccdb", db_name: "ccdb", endpoint_port: 1234, db_instance_status: :irrelevant)
        fake_uaadb_rds = mock("uaadb", db_name: "uaadb", endpoint_port: 5678, db_instance_status: :irrelevant)
        fake_rds.should_receive(:databases).at_least(:once).and_return([fake_ccdb_rds, fake_uaadb_rds])

        ccdb_endpoint_address_response = ([nil] * retries_needed) << "1.2.3.4"
        fake_ccdb_rds.stub(:endpoint_address).and_return(*ccdb_endpoint_address_response)

        uaadb_endpoint_address_response = ([nil] * retries_needed) << "5.6.7.8"
        fake_uaadb_rds.stub(:endpoint_address).and_return(*uaadb_endpoint_address_response)

        fake_rds.stub(:database).with("ccdb").and_return(fake_ccdb_rds)
        fake_rds.stub(:database).with("uaadb").and_return(fake_uaadb_rds)

        fake_rds
      end

      it "should create all rds databases" do
        fake_aws_rds = make_fake_rds!
        aws.create_rds_dbs(config_file, receipt_file)
      end

      it "should do nothing if rds config is empty" do
        aws.stub(:load_yaml_file).and_return({})

        aws.should_receive(:say).with("rds not set in config.  Skipping")

        aws.create_rds_dbs(config_file, receipt_file)
      end

      context "when the config file has option overrides" do
        let(:config_file) { asset "config_with_override.yml" }

        # TODO: Where are the assertions for this test?  Buried in `make_fake_rds!`?  Fix this!
        it "should create all rds databases with option overrides" do
          ccdb_opts = YAML.load_file(config_file)["rds"].find { |db_opts| db_opts["name"] == "ccdb" }
          make_fake_rds!(aws_creation_options: ccdb_opts["aws_creation_options"])
          aws.create_rds_dbs(config_file, receipt_file)
        end
      end

      it "should flush the output to a YAML file" do
        make_fake_rds!

        aws.should_receive(:flush_output_state) do |args|
          args.should match(/aws_rds_receipt.yml/)
        end

        aws.create_rds_dbs(config_file, receipt_file)

        deployment_manifest_properties = aws.output_state["deployment_manifest"]["properties"]

        deployment_manifest_properties["ccdb"].should == {
            "db_scheme" => "mysql",
            "address" => "1.2.3.4",
            "port" => 1234,
            "roles" => [
                {
                    "tag" => "admin",
                    "name" => "ccdb_user",
                    "password" => "ccdb_password"
                }
            ],
            "databases" => [
                {
                    "tag" => "cc",
                    "name" => "ccdb"
                }
            ]
        }

        deployment_manifest_properties["uaadb"].should == {
            "db_scheme" => "mysql",
            "address" => "5.6.7.8",
            "port" => 5678,
            "roles" => [
                {
                    "tag" => "admin",
                    "name" => "uaa_user",
                    "password" => "uaa_password"
                }
            ],
            "databases" => [
                {
                    "tag" => "uaa",
                    "name" => "uaadb"
                }
            ]
        }
      end

      context "when the RDS is not immediately available" do

        # TODO: Where are the assertions for this test?  Buried in `make_fake_rds!`?  Fix this!
        it "should try several times and continue when available" do
          make_fake_rds!(retries_needed: 3)
          aws.create_rds_dbs(config_file, receipt_file)
        end

        it "should fail after 180 attempts when not available" do
          make_fake_rds!(retries_needed: 181)
          expect { aws.create_rds_dbs(config_file, receipt_file) }.to raise_error
        end
      end
    end

    describe "aws delete_all rds databases" do
      let(:config_file) { asset "config.yml" }

      it "should warn the user that the operation is destructive and list the instances" do
        fake_ec2 = mock("ec2")
        Bosh::Aws::EC2.stub(:new).and_return(fake_ec2)
        fake_ec2.stub(:instances_count).and_return(20)
        fake_rds = mock("rds")
        fake_rds.stub(:database_names).and_return({"instance1" => "bosh_db", "instance2" => "important_db"})
        fake_rds.stub(:databases).and_return([])

        Bosh::Aws::RDS.stub(:new).and_return(fake_rds)

        aws.should_receive(:say).with("THIS IS A VERY DESTRUCTIVE OPERATION AND IT CANNOT BE UNDONE!\n".red)
        aws.should_receive(:say).
            with("Database Instances:\n\tinstance1\t(database_name: bosh_db)\n\tinstance2\t(database_name: important_db)")
        aws.should_receive(:confirmed?).with("Are you sure you want to delete all databases?").
            and_return(false)

        aws.delete_all_rds_dbs(config_file)
      end

      it "should not delete_all rds databases if more than 20 insances are running" do
        fake_ec2 = mock("ec2")
        Bosh::Aws::EC2.stub(:new).and_return(fake_ec2)
        fake_ec2.stub(:instances_count).and_return(21)

        expect {
          aws.delete_all_rds_dbs config_file
        }.to raise_error(Bosh::Cli::CliError, "21 instance(s) running.  This isn't a dev account (more than 20) please make sure you want to do this, aborting.")
      end

      it "should delete db_subnets when dbs don't exist" do
        fake_ec2 = mock("ec2")
        Bosh::Aws::EC2.stub(:new).and_return(fake_ec2)
        fake_ec2.stub(:instances_count).and_return(20)

        fake_rds = mock("rds")
        fake_rds.should_receive(:database_names).and_return([])
        fake_rds.should_receive(:databases).and_return([])
        fake_rds.should_not_receive(:delete_databases)
        fake_rds.should_receive(:delete_subnet_groups)
        fake_rds.should_receive(:delete_security_groups)
        Bosh::Aws::RDS.stub(:new).and_return(fake_rds)

        aws.should_receive(:confirmed?).with("Are you sure you want to delete all databases?").
            and_return(true)

        aws.delete_all_rds_dbs config_file

      end

      context "interactive mode (default)" do
        before do
          fake_ec2 = mock("ec2")
          Bosh::Aws::EC2.stub(:new).and_return(fake_ec2)
          fake_ec2.stub(:instances_count).and_return(20)
        end

        context "when the user agrees to delete all the databases" do
          it "should delete all databases" do
            fake_rds = mock("rds")

            Bosh::Aws::RDS.stub(:new).and_return(fake_rds)
            aws.stub(:say).twice
            aws.stub(:confirmed?).and_return(true)
            fake_rds.stub(:database_names).and_return(%w[foo bar])
            fake_rds.stub(:databases).and_return([])

            fake_rds.should_receive :delete_databases
            fake_rds.should_receive :delete_subnet_groups
            fake_rds.should_receive :delete_security_groups

            aws.delete_all_rds_dbs(config_file)
          end
        end

        context "when the user wants to bail out of rds database deletion" do
          it "should not terminate any databases" do
            fake_rds = mock("rds")

            Bosh::Aws::RDS.stub(:new).and_return(fake_rds)
            aws.stub(:say).twice
            aws.stub(:confirmed?).and_return(false)
            fake_rds.stub(:database_names).and_return(double.as_null_object)

            fake_rds.should_not_receive :delete_databases

            aws.delete_all_rds_dbs(config_file)
          end
        end

        context "when not all instances could be deleted" do
          it "throws a nice error message" do
            fake_rds = mock("rds")
            Bosh::Aws::RDS.stub(:new).and_return(fake_rds)
            fake_rds.stub(:database_names).and_return({"instance1" => "bosh_db", "instance2" => "important_db"})
            fake_bosh_rds = mock("instance1", db_name: "bosh_db", endpoint_port: 1234, db_instance_status: :irrelevant)
            fake_rds.stub(:databases).and_return([fake_bosh_rds])

            ::Bosh::Cli::Command::Base.any_instance.stub(:non_interactive?).and_return(true)

            fake_rds.should_receive :delete_databases

            expect {
              aws.delete_all_rds_dbs(config_file)
            }.to raise_error(Bosh::Cli::CliError, "not all rds instances could be deleted")
          end

          context "when a database goes away while printing status" do
            it "should delete all databases" do
              fake_rds = mock("rds")
              Bosh::Aws::RDS.stub(:new).and_return(fake_rds)
              fake_rds.stub(:database_names).and_return({"instance1" => "bosh_db", "instance2" => "important_db"})
              fake_bosh_rds = mock("instance1", db_name: "bosh_db", endpoint_port: 1234, db_instance_status: :irrelevant)
              fake_bosh_rds.should_receive(:db_name).and_raise(::AWS::RDS::Errors::DBInstanceNotFound)

              fake_rds.should_receive(:databases).and_return([fake_bosh_rds], [fake_bosh_rds], [])

              ::Bosh::Cli::Command::Base.any_instance.stub(:non_interactive?).and_return(true)

              fake_rds.should_receive :delete_databases
              fake_rds.should_receive :delete_subnet_groups
              fake_rds.should_receive :delete_security_groups

              aws.delete_all_rds_dbs(config_file)
            end
          end
        end
      end

      context "non-interactive mode" do
        it "should delete all databases" do
          fake_ec2 = mock("ec2")
          Bosh::Aws::EC2.stub(:new).and_return(fake_ec2)
          fake_ec2.stub(:instances_count).and_return(20)
          fake_rds = mock("rds")

          Bosh::Aws::RDS.stub(:new).and_return(fake_rds)
          aws.stub(:say).twice
          fake_rds.stub_chain(:database_names, :map).and_return(["database_name: foo"])
          fake_rds.stub(:databases).and_return([])

          fake_rds.should_receive :delete_databases
          fake_rds.should_receive :delete_subnet_groups
          fake_rds.should_receive :delete_security_groups

          ::Bosh::Cli::Command::Base.any_instance.stub(:non_interactive?).and_return(true)
          aws.delete_all_rds_dbs(config_file)
        end
      end
    end

    describe "aws delete_all rds subnet_groups" do
      let(:config_file) { asset "config.yml" }

      it "should remove all RDS subnet grops" do
        fake_rds = mock("rds")
        Bosh::Aws::RDS.stub(:new).and_return(fake_rds)
        fake_rds.should_receive :delete_subnet_groups
        aws.delete_all_rds_subnet_groups(config_file)
      end
    end

    describe "aws delete_all rds security_groups" do
      let(:config_file) { asset "config.yml" }

      it "should remove all RDS subnet grops" do
        fake_rds = mock("rds")
        Bosh::Aws::RDS.stub(:new).and_return(fake_rds)
        fake_rds.should_receive :delete_security_groups
        aws.delete_all_rds_security_groups(config_file)
      end
    end

    describe "aws delete_all elbs" do
      let(:config_file) { asset "config.yml" }

      it "should remove all ELBs" do
        fake_elb = mock("elb")
        Bosh::Aws::ELB.stub(:new).and_return(fake_elb)
        fake_elb.should_receive :delete_elbs
        fake_elb.should_receive(:names).and_return(%w(one two))
        aws.should_receive(:confirmed?).and_return(true)
        aws.delete_all_elbs(config_file)
      end
    end
  end

  describe "micro_ami" do
    context "when the environment provides an override AMI" do
      before(:all) do
        ENV["BOSH_OVERRIDE_MICRO_STEMCELL_AMI"] = 'ami-tgupta'
      end

      after(:all) do
        ENV.delete "BOSH_OVERRIDE_MICRO_STEMCELL_AMI"
      end

      it "uses the given AMI" do
        aws.micro_ami.should == 'ami-tgupta'
      end
    end

    context "when the environment does not provide an override AMI" do
      before do
        Net::HTTP.should_receive(:get).with("bosh-jenkins-artifacts.s3.amazonaws.com", "/last_successful_micro-bosh-stemcell_ami").and_return("ami-david")
      end

      it "returns the content from S3" do
        aws.micro_ami.should == "ami-david"
      end
    end
  end
end
