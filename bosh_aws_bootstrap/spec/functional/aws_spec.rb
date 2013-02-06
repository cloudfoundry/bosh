require 'spec_helper'

describe Bosh::Cli::Command::AWS do
  let(:aws) { subject }
  before { aws.stub(:sleep)  }

  describe "command line tools" do
    describe "aws create vpc" do
      let(:config_file) { asset "config.yml" }

      def make_fake_vpc!(overrides = {})
        fake_ec2 = mock("ec2")
        fake_vpc = mock("vpc")
        fake_route53 = mock("route53")

        Bosh::Aws::EC2.stub(:new).and_return(fake_ec2)
        Bosh::Aws::VPC.stub(:create).and_return(fake_vpc)
        Bosh::Aws::Route53.stub(:new).and_return(fake_route53)

        fake_vpc.stub(:vpc_id).and_return("vpc id")
        fake_vpc.stub(:create_dhcp_options)
        fake_vpc.stub(:create_security_groups)
        fake_vpc.stub(:create_subnets)
        fake_vpc.stub(:subnet_ids).and_return(["amz-subnet1"])
        fake_vpc.stub(:attach_internet_gateway)
        fake_ec2.stub(:allocate_elastic_ips)
        fake_ec2.stub(:add_key_pair)
        fake_ec2.stub(:create_internet_gateway)
        fake_ec2.stub(:internet_gateway_ids).and_return(["id1", "id2"])
        fake_ec2.stub(:elastic_ips).and_return(["1.2.3.4", "5.6.7.8"])
        fake_route53.stub(:create_zone)
        fake_route53.stub(:add_record)
        fake_vpc
      end

      it "should create all the components of the vpc" do
        fake_ec2 = mock("ec2")
        fake_vpc = mock("vpc")
        fake_route53 = mock("route53")

        Bosh::Aws::EC2.stub(:new).and_return(fake_ec2)
        Bosh::Aws::VPC.stub(:create).with(fake_ec2, "10.10.0.0/16", "default").and_return(fake_vpc)
        Bosh::Aws::Route53.stub(:new).and_return(fake_route53)

        fake_vpc.stub(:vpc_id)

        fake_vpc.should_receive(:create_subnets).with [
                                                          {"cidr" => "10.10.0.0/24", "availability_zone" => "us-east-1a"},
                                                          {"cidr" => "10.10.1.0/24", "availability_zone" => "us-east-1b"}
                                                      ]
        fake_vpc.should_receive(:create_dhcp_options).with(
            "domain_name" => "dev102.cf.com",
            "domain_name_servers" => ["10.10.0.5", "172.16.0.23"]
        )
        fake_vpc.should_receive(:create_security_groups) do |args|
          args.length.should == 2
          args.first.keys.should =~ %w[name ingress]
        end
        fake_ec2.should_receive(:allocate_elastic_ips).with(2)
        fake_ec2.should_receive(:add_key_pair).with("somename", "/tmp/somekey")
        fake_ec2.should_receive(:create_internet_gateway)
        fake_ec2.should_receive(:internet_gateway_ids).and_return(["id1", "id2"])
        fake_vpc.should_receive(:attach_internet_gateway).with("id1")

        fake_vpc.stub(:subnet_ids)
        fake_ec2.stub(:elastic_ips).and_return(["107.23.46.162", "107.23.53.76"])
        fake_vpc.stub(:flush_output_state)
        fake_vpc.stub(:state).and_return(:available)

        fake_route53.should_receive(:add_record).with("*", "dev102.cf.com", ["107.23.46.162", "107.23.53.76"])

        aws.create_vpc config_file
      end

      it "should flush the output to a YAML file" do
        fake_vpc = make_fake_vpc!
        fake_vpc.stub(:state).and_return(:available)

        aws.should_receive(:flush_output_state) do |args|
          args.should match(/create-vpc-output-\d{14}.yml/)
        end

        aws.create_vpc config_file

        aws.output_state["vpc"]["id"].should == "vpc id"
        aws.output_state["vpc"]["subnet_ids"].should == ["amz-subnet1"]
        aws.output_state["elastic_ips"]["router"]["ips"].should == ["1.2.3.4", "5.6.7.8"]
        aws.output_state["elastic_ips"]["router"]["dns_record"].should == "*"
        aws.output_state["key_pairs"].should == ["somename"]
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
        fake_route53.should_receive(:delete_record).with("*", "cfdev.com")

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
        aws.should_receive(:agree).with("Are you sure you want to empty and delete all buckets?").and_return(false)

        aws.empty_s3 config_file
      end

      it "should not empty S3 if more than 20 insances are running" do
        fake_ec2 = mock("ec2")
        Bosh::Aws::EC2.stub(:new).and_return(fake_ec2)
        fake_ec2.stub(:instances_count).and_return(21)

        expect {
          aws.empty_s3 config_file
        }.to raise_error(Bosh::Cli::CliError, "21 instance(s) running.  This isn't a dev account (more than 20) please make sure you want to do this, aborting.")
      end

      context "interactive mode (default)" do
        context "when the users agrees to nuke the buckets" do
          it "should empty and delete all S3 buckets associated with an account" do
            fake_ec2 = mock("ec2")
            Bosh::Aws::EC2.stub(:new).and_return(fake_ec2)
            fake_ec2.stub(:instances_count).and_return(20)
            fake_s3 = mock("s3")

            Bosh::Aws::S3.stub(:new).and_return(fake_s3)
            fake_s3.stub(:bucket_names).and_return(double.as_null_object)

            aws.stub(:say).twice
            aws.stub(:agree).and_return(true)

            fake_s3.should_receive :empty

            aws.empty_s3 config_file
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
            aws.stub(:agree).and_return(false)

            fake_s3.should_not_receive :empty

            aws.empty_s3 config_file
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
          fake_s3.stub(:bucket_names).and_return(double.as_null_object)
          aws.stub(:say).twice

          fake_s3.should_receive :empty

          ::Bosh::Cli::Command::Base.any_instance.stub(:non_interactive?).and_return(true)
          aws.empty_s3 config_file
        end
      end
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
        aws.should_receive(:agree).
            with("Are you sure you want to terminate all EC2 instances and their associated EBS volumes?").
            and_return(false)

        aws.terminate_all_ec2 config_file
      end

      it "should error if more than 20 instances are running" do
        fake_ec2 = mock("ec2")
        Bosh::Aws::EC2.stub(:new).and_return(fake_ec2)
        fake_ec2.stub(:instances_count).and_return(21)

        expect {
          aws.terminate_all_ec2 config_file
        }.to raise_error(Bosh::Cli::CliError, "21 instance(s) running.  This isn't a dev account (more than 20) please make sure you want to do this, aborting.")
      end

      context "interactive mode (default)" do
        context 'when the user agrees to terminate all the instances' do
          it 'should terminate all instances' do
            fake_ec2 = mock("ec2")

            Bosh::Aws::EC2.stub(:new).and_return(fake_ec2)
            aws.stub(:say)
            aws.stub(:agree).and_return(true)
            fake_ec2.stub(:instances_count).and_return(0)
            fake_ec2.stub(:instance_names).and_return(double.as_null_object)

            fake_ec2.should_receive :terminate_instances

            aws.terminate_all_ec2(config_file)
          end
        end

        context 'when the user wants to bail out of ec2 termination' do
          it 'should not terminate any instances' do
            fake_ec2 = mock("ec2")

            Bosh::Aws::EC2.stub(:new).and_return(fake_ec2)
            aws.stub(:say).twice
            aws.stub(:agree).and_return(false)
            fake_ec2.stub(:instances_count).and_return(0)
            fake_ec2.stub(:instance_names).and_return(double.as_null_object)

            fake_ec2.should_not_receive :terminate_instances

            aws.terminate_all_ec2 config_file
          end
        end
      end

      context "non-interactive mode" do
        it 'should terminate all instances' do
          fake_ec2 = mock("ec2")

          Bosh::Aws::EC2.stub(:new).and_return(fake_ec2)
          aws.stub(:say)
          fake_ec2.stub(:instances_count).and_return(0)
          fake_ec2.stub(:instance_names).and_return(double.as_null_object)

          fake_ec2.should_receive :terminate_instances

          ::Bosh::Cli::Command::Base.any_instance.stub(:non_interactive?).and_return(true)
          aws.terminate_all_ec2(config_file)
        end
      end
    end

    describe "aws snapshot director deployments" do
      let(:config_file) { asset "config.yml" }

      it "should snapshot EBS volumes in all deployments" do
        bat_vm_fixtures = [
            {"agent_id" => "a1b2", "cid" => "i-a1b2c3" ,"job" => "director", "index" => 0},
            {"agent_id" => "a3b4", "cid" => "i-d4e5f6" ,"job" => "postgres", "index" => 0}
        ]
        bosh_vm_fixtures = [
            {"agent_id" => "a1b2", "cid" => "i-g1h2i3" ,"job" => "director", "index" => 0}
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
            and_return({"/dev/sda" => fake_attachment,"/dev/sdb" => fake_attachment})
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

    describe "aws delete_all rds databases" do
      let(:config_file) { asset "config.yml" }

      it "should warn the user that the operation is destructive and list the instances" do
        fake_ec2 = mock("ec2")
        Bosh::Aws::EC2.stub(:new).and_return(fake_ec2)
        fake_ec2.stub(:instances_count).and_return(20)
        fake_rds = mock("rds")
        fake_rds.stub(:database_names).and_return({"instance1" => "bosh_db", "instance2" => "important_db"})

        Bosh::Aws::RDS.stub(:new).and_return(fake_rds)

        aws.should_receive(:say).with("THIS IS A VERY DESTRUCTIVE OPERATION AND IT CANNOT BE UNDONE!\n".red)
        aws.should_receive(:say).
            with("Database Instances:\n\tinstance1\t(database_name: bosh_db)\n\tinstance2\t(database_name: important_db)")
        aws.should_receive(:agree).with("Are you sure you want to delete all databases?").
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
            aws.stub(:agree).and_return(true)
            fake_rds.stub(:database_names).and_return(double.as_null_object)

            fake_rds.should_receive :delete_databases

            aws.delete_all_rds_dbs(config_file)
          end
        end

        context "when the user wants to bail out of rds database deletion" do
          it "should not terminate any databases" do
            fake_rds = mock("rds")

            Bosh::Aws::RDS.stub(:new).and_return(fake_rds)
            aws.stub(:say).twice
            aws.stub(:agree).and_return(false)
            fake_rds.stub(:database_names).and_return(double.as_null_object)

            fake_rds.should_not_receive :delete_databases

            aws.delete_all_rds_dbs(config_file)
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
          fake_rds.stub(:database_names).and_return(double.as_null_object)

          fake_rds.should_receive :delete_databases

          ::Bosh::Cli::Command::Base.any_instance.stub(:non_interactive?).and_return(true)
          aws.delete_all_rds_dbs(config_file)
        end
      end
    end
  end
end
