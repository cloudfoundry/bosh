require 'spec_helper'

describe Bosh::Cli::Command::AWS do
  let(:aws) { subject }
  let(:default_config_filename) do
    File.expand_path(File.join(
      File.dirname(__FILE__), '..', '..', 'templates', 'aws_configuration_template.yml.erb'
    ))
  end

  before { aws.stub(:sleep) }

  describe 'command line tools' do
    describe 'aws generate micro_bosh' do
      let(:create_vpc_output_yml) { asset 'test-output.yml' }
      let(:route53_receipt_yml) { asset 'test-aws_route53_receipt.yml' }
      let(:micro_bosh_yaml) { Psych.load_file('micro_bosh.yml') }

      around do |test|
        Dir.mktmpdir do |dir|
          Dir.chdir(dir) do
            aws.create_micro_bosh_manifest(create_vpc_output_yml, route53_receipt_yml)
            test.run
          end
        end
      end

      it 'uses some of the normal director keys' do
        micro_bosh_yaml['name'].should == 'micro-dev102'
        micro_bosh_yaml['network']['vip'].should == '50.200.100.1'
        micro_bosh_yaml['network']['cloud_properties']['subnet'].should == 'subnet-4bdf6c26'
        micro_bosh_yaml['resources']['cloud_properties']['availability_zone'].should == 'us-east-1a'

        micro_bosh_yaml['cloud']['properties']['aws']['access_key_id'].should == '...'
        micro_bosh_yaml['cloud']['properties']['aws']['secret_access_key'].should == '...'
        micro_bosh_yaml['cloud']['properties']['aws']['region'].should == 'us-east-1'
      end

      it 'has a health manager username and password populated' do
        micro_bosh_yaml['apply_spec']['properties']['hm']['director_account']['user'].should == 'hm'
        micro_bosh_yaml['apply_spec']['properties']['hm']['director_account']['password'].should_not be_nil
      end
    end

    describe 'aws generate bosh' do
      let(:create_vpc_output_yml) { asset 'test-output.yml' }
      let(:route53_receipt_yml) { asset 'test-aws_route53_receipt.yml' }
      let(:bosh_rds_receipt_yml) { asset 'test-aws_rds_bosh_receipt.yml' }

      it 'generates required bosh deployment keys' do
        Dir.mktmpdir do |dir|
          Dir.chdir(dir) do
            aws.stub(:target_required)
            aws.stub_chain(:director, :uuid).and_return('deadbeef')
            aws.create_bosh_manifest(create_vpc_output_yml, route53_receipt_yml, bosh_rds_receipt_yml)

            yaml = Psych.load_file('bosh.yml')

            yaml['name'].should == 'vpc-bosh-dev102'
            yaml['properties']['hm']['director_account']['user'].should == 'hm'
            yaml['properties']['hm']['director_account']['password'].should_not be_nil
          end
        end
      end
    end

    describe 'aws generate bat' do
      let(:create_vpc_output_yml) { asset 'test-output.yml' }
      let(:route53_receipt_yml) { asset 'test-aws_route53_receipt.yml' }

      it 'has the correct stemcell name' do
        aws.stub(:target_required)
        aws.stub_chain(:director, :uuid).and_return('deadbeef')

        Dir.mktmpdir do |dir|
          Dir.chdir(dir) do
            aws.create_bat_manifest(create_vpc_output_yml, route53_receipt_yml, 123, 'test-stemcell')
            yaml = Psych.load_file('bat.yml')
            expect(yaml['resource_pools'].first['stemcell']['name']).to eq 'test-stemcell'
            expect(yaml['properties']['stemcell']['name']).to eq 'test-stemcell'
          end
        end
      end
    end

    describe 'aws create' do
      let(:config_file) { asset 'create_all.yml' }
      let(:migrator) { double('Migrator') }

      around do |example|
        previous_env = ENV.to_hash

        ENV['BOSH_AWS_SECRET_ACCESS_KEY'] = 'fake secret access key'
        ENV['BOSH_AWS_ACCESS_KEY_ID'] = 'fake access key id'
        ENV['BOSH_VPC_SUBDOMAIN'] = 'fake vpc subdomain'
        ENV['BOSH_VPC_PRIMARY_AZ'] = 'fake az'
        ENV['BOSH_VPC_SECONDARY_AZ'] = 'fake secondary az'

        example.run

        previous_env.each { |k, v| ENV[k] = v }
      end

      it 'should run the migrations' do
        Bosh::Aws::Migrator.should_receive(:new).with(YAML.load_yaml_file(config_file)).and_return(migrator)
        migrator.should_receive(:migrate)
        aws.create config_file
      end

      it 'should default the configuration file when not passed in' do
        File.exist?(default_config_filename).should == true
        Bosh::Aws::Migrator.should_receive(:new).and_return(migrator)
        migrator.should_receive(:migrate)
        aws.create
      end
    end

    describe 'aws destroy' do
      before { Bosh::Aws::Destroyer.stub(:new).with(aws, config, rds_destroyer, vpc_destroyer).and_return(destroyer) }
      let(:destroyer) { instance_double('Bosh::Aws::Destroyer') }

      before { Bosh::Aws::RdsDestroyer.stub(:new).with(aws, config).and_return(rds_destroyer) }
      let(:rds_destroyer) { instance_double('Bosh::Aws::RdsDestroyer') }

      before { Bosh::Aws::VpcDestroyer.stub(:new).with(aws, config).and_return(vpc_destroyer) }
      let(:vpc_destroyer) { instance_double('Bosh::Aws::VpcDestroyer') }

      before { aws.stub(:load_config).with(config_file).and_return(config) }
      let(:config_file) { double('config_file') }
      let(:config) { { fake: 'config' } }

      it 'destroys the specified VPCs, RDS DBs, and S3 Volumes' do
        destroyer.should_receive(:ensure_not_production!).ordered
        destroyer.should_receive(:delete_all_elbs).ordered
        destroyer.should_receive(:delete_all_ec2).ordered
        destroyer.should_receive(:delete_all_ebs).ordered
        destroyer.should_receive(:delete_all_rds).ordered
        destroyer.should_receive(:delete_all_s3).ordered
        destroyer.should_receive(:delete_all_vpcs).ordered
        destroyer.should_receive(:delete_all_key_pairs).ordered
        destroyer.should_receive(:delete_all_elastic_ips).ordered
        destroyer.should_receive(:delete_all_security_groups).ordered
        destroyer.should_receive(:delete_all_route53_records).ordered
        aws.destroy(config_file)
      end
    end

    describe 'load_config' do
      let(:config_file) { double('config_file') }
      let(:config) { instance_double('Bosh::Aws::AwsConfig', configuration: 'fake_configuration') }

      context 'when a config file is provided' do
        it 'uses the provided file' do
          Bosh::Aws::AwsConfig.should_receive(:new).with(config_file).and_return(config)
          expect(aws.send(:load_config, config_file)).to eq('fake_configuration')
        end
      end

      context 'when a config file is not provided' do
        it 'uses a default config' do
          Bosh::Aws::AwsConfig.should_receive(:new).with(default_config_filename).and_return(config)
          expect(aws.send(:load_config)).to eq('fake_configuration')
        end
      end
    end

    describe 'aws bootstrap micro' do
      subject(:aws) { described_class.new }
      let(:fake_bootstrap) { double('micro bosh bootstrap') }
      context 'interative' do
        before(:each) do
          aws.options[:non_interactive] = false
        end

        it 'prompts the user for admin password' do
          fake_bootstrap.should_receive(:start)
          Bosh::Aws::MicroBoshBootstrap.should_receive(:new).with(
            anything,
            kind_of(Hash)
          ).and_return(fake_bootstrap)
          aws.should_receive(:ask).and_return('username')
          aws.should_receive(:ask).and_return('password')

          fake_bootstrap.should_receive(:create_user).with('hm', anything).ordered
          fake_bootstrap.should_receive(:create_user).with('username', 'password').ordered

          aws.bootstrap_micro
        end
      end

      context 'non-interactive' do
        before(:each) do
          aws.options[:non_interactive] = true
        end

        it 'saves the randomly generated password??' do
          fake_bootstrap.should_receive(:start)
          Bosh::Aws::MicroBoshBootstrap.should_receive(:new).with(
            anything,
            kind_of(Hash)
          ).and_return(fake_bootstrap)

          fake_bootstrap.should_receive(:create_user).with('hm', anything).ordered
          fake_bootstrap.should_receive(:create_user).with('admin', anything).ordered

          aws.bootstrap_micro
        end
      end
    end
  end
end
