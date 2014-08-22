require 'spec_helper'

describe 'AWS Bootstrap commands' do
  let(:aws) { Bosh::Cli::Command::AWS.new }
  let(:mock_s3) { double(Bosh::Aws::S3) }
  let(:bosh_config)  { File.expand_path(File.join(File.dirname(__FILE__), '..', 'assets', 'bosh_config.yml')) }

  before do
    aws.options[:non_interactive] = true

    WebMock.disable_net_connect!
    aws.stub(:sleep)
    aws.stub(:s3).and_return(mock_s3)
  end

  around do |example|

    @bosh_config = Tempfile.new('bosh_config')
    FileUtils.cp(bosh_config, @bosh_config.path)
    aws.add_option(:config, @bosh_config.path)

    FileUtils.cp(asset('id_spec_rsa'), '/tmp/somekey')

    Dir.mktmpdir do |dirname|
      Dir.chdir dirname do
        FileUtils.cp(asset('test-output.yml'), 'aws_vpc_receipt.yml')
        FileUtils.cp(asset('test-aws_route53_receipt.yml'), 'aws_route53_receipt.yml')
        FileUtils.cp(asset('test-aws_rds_bosh_receipt.yml'), 'aws_rds_bosh_receipt.yml')

        example.run
      end
    end

    FileUtils.rm('/tmp/somekey')

    @bosh_config.close
  end

  describe 'aws bootstrap micro' do
    context 'when non-interactive' do
      let(:misc_command) { double('Command Misc') }
      let(:user_command) { double('Command User') }

      before do
        Bosh::Cli::Command::User.stub(:new).and_return(user_command)
        Bosh::Cli::Command::Misc.stub(:new).and_return(misc_command)
        misc_command.stub(:options=)
        user_command.stub(:options=)
      end

      it 'should bootstrap microbosh' do
        stemcell_ami_request = stub_request(:get, 'http://bosh-jenkins-artifacts.s3.amazonaws.com/last_successful-bosh-stemcell-aws_ami_us-east-1').
            to_return(:status => 200, :body => 'ami-0e3da467', :headers => {})

        SecureRandom.should_receive(:base64).and_return('hm_password')
        SecureRandom.should_receive(:base64).and_return('admin_password')

        misc_command.should_receive(:login).with('admin', 'admin')
        user_command.should_receive(:create).with('admin', 'admin_password').and_return(true)
        misc_command.should_receive(:login).with('admin', 'admin_password')
        user_command.should_receive(:create).with('hm', 'hm_password').and_return(true)
        misc_command.should_receive(:login).with('hm', 'hm_password')

        Bosh::Deployer::InstanceManager.any_instance.should_receive(:with_lifecycle)

        aws.bootstrap_micro

        stemcell_ami_request.should have_been_made
      end

      context 'hm user and password' do
        let(:fake_bootstrap) { double('MicroBosh Bootstrap', start: true) }
        before do
          Bosh::Aws::MicroBoshBootstrap.stub(:new).and_return(fake_bootstrap)
        end

        it "creates default 'hm' user name for hm" do
          fake_bootstrap.stub(:create_user)

          fake_bootstrap.should_receive(:create_user).with('hm', anything)
          aws.bootstrap_micro
        end

        it 'passes the generated hm user to the new microbosh bootstrapper' do
          SecureRandom.stub(:base64).and_return('some_password')
          fake_bootstrap.stub(:create_user)
          Bosh::Aws::MicroBoshBootstrap.should_receive(:new) do |_, options|
            options[:hm_director_user].should == 'hm'
            options[:hm_director_password].should == 'some_password'
            fake_bootstrap
          end
          aws.bootstrap_micro
        end

        it 'creates a hm user with name from options' do
          aws.options[:hm_director_user] = 'hm_guy'
          fake_bootstrap.stub(:create_user)
          fake_bootstrap.should_receive(:create_user).with('hm_guy', anything)
          aws.bootstrap_micro
        end
      end

    end

    context 'when interactive' do
      before do
        aws.options[:non_interactive] = false

      end

      it 'should ask for a new user' do
        fake_bootstrap = double('MicroBosh Bootstrap', start: true)
        Bosh::Aws::MicroBoshBootstrap.stub(:new).and_return(fake_bootstrap)

        aws.should_receive(:ask).with('Enter username: ').and_return('admin')
        aws.should_receive(:ask).with('Enter password: ').and_return('admin_passwd')
        fake_bootstrap.should_receive(:create_user).with('admin', 'admin_passwd')
        fake_bootstrap.should_receive(:create_user).with('hm', anything)

        aws.bootstrap_micro
      end
    end
  end

  describe 'aws bootstrap bosh' do
    let(:deployment_name) { 'vpc-bosh-test' }
    let(:stemcell_stub)  { File.expand_path(File.join(File.dirname(__FILE__), '..', 'assets', 'stemcell_stub.tgz')) }

    let(:deployments) do
      [
          {
              'name' => deployment_name,
              'releases' => [{ 'name' => 'bosh', 'version' => '13.1-dev' }],
              'stemcells' => [{ 'name' => 'stemcell-name', 'version' => '2013-03-21_01-53-17' }]
          }
      ]
    end

    before do
      stub_request(:get, 'http://127.0.0.1:25555/info').
          with(:headers => {'Content-Type' => 'application/json'}).
          to_return(:status => 200, :body => '{"uuid": "1234abc"}')

      Bosh::Cli::Config.output = File.open('/dev/null', 'w')

      aws.options[:username] = 'bosh_user'
      aws.options[:password] = 'bosh_password'
    end

    context 'when the target is not set' do
      before do
        aws.options[:target] = nil
        aws.config.target = nil
      end

      it 'raises an error' do
        expect { aws.bootstrap_bosh }.to raise_error(/Please choose target first/)
      end
    end

    context 'when the target already has a release, possibly a stemcell' do
      before do
        aws.config.target = aws.options[:target] = 'http://localhost:25555'

        releases = [
            {
                'name' => 'bosh',
                'release_versions' => [
                    {
                        'version' => '13.1-dev',
                        'commit_hash' => '5c9d7254',
                        'uncommitted_changes' => false,
                        'currently_deployed' => true
                    }
                ]
            }
        ]

        stub_request(:get, 'http://127.0.0.1:25555/stemcells').
            to_return(:status => 200, :body => '[{"name":"bosh-stemcell-ubuntu","version":"2013-03-21_01-53-17","cid":"ami-1c990175"}]')
        stub_request(:get, 'http://127.0.0.1:25555/releases').
            with(:headers => {'Content-Type' => 'application/json'}).
            to_return(:status => 200, :body => releases.to_json)
        stub_request(:get, 'http://127.0.0.1:25555/deployments').
            to_return(:status => 200, :body => '[]')
        stub_request(:get, 'http://127.0.0.1:25555/deployments/vpc-bosh-dev102/properties').
            to_return(:status => 200, :body => '')

        # Skip the actual deploy, since we already test it later on
        Bosh::Aws::BoshBootstrap.any_instance.stub(:deploy)
        Bosh::Aws::BoshBootstrap.any_instance.stub(:target_bosh_and_log_in)
        Bosh::Aws::BoshBootstrap.any_instance.stub(:create_user)
        Bosh::Cli::Command::AWS.any_instance.stub(:ask).and_return('foo')

      end

      it 'use the existent release' do
        mock_s3.should_not_receive(:copy_remote_file)
        Bosh::Exec.should_not_receive(:sh).with('bundle exec rake release:create_dev_release')
        Bosh::Cli::Command::Release::UploadRelease.any_instance.should_not_receive(:upload)

        expect do
          aws.bootstrap_bosh
        end.to_not raise_error
      end

      it 'use the existent stemcell' do
        mock_s3.should_not_receive(:copy_remote_file)
        Bosh::Cli::Command::Stemcell.any_instance.should_not_receive(:upload)
        expect do
          aws.bootstrap_bosh
        end.to_not raise_error
      end

      context 'when the target has no stemcell' do
        let(:stemcell_archive) { instance_double('Bosh::Stemcell::Archive', name: 'bosh-stemcell-ubuntu')}
        it 'uploads a stemcell' do
          stub_request(:get, 'http://127.0.0.1:25555/stemcells').
            to_return(status: 200, body: '[]')
          mock_s3.should_receive(:copy_remote_file).and_return '/tmp/bosh_stemcell.tgz'
          Bosh::Stemcell::Archive.should_receive(:new).with('/tmp/bosh_stemcell.tgz').and_return(stemcell_archive)
          Bosh::Cli::Command::Stemcell.any_instance.should_receive(:upload)
          aws.bootstrap_bosh
        end
      end
    end

    context 'when the target already have a deployment' do
      # This deployment name comes from test-output.yml asset file.
      let(:deployment_name) { 'vpc-bosh-dev102' }

      before do
        aws.options[:target] = 'http://localhost:25555'

        stub_request(:get, 'http://127.0.0.1:25555/releases').
            with(:headers => {'Content-Type' => 'application/json'}).
            to_return(:status => 200, :body => '[]')

        stub_request(:get, 'http://127.0.0.1:25555/deployments').
            with(:headers => {'Content-Type' => 'application/json'}).
            to_return(:status => 200, :body => deployments.to_json)

        stub_request(:get, 'http://127.0.0.1:25555/stemcells').
            with(:headers => {'Content-Type' => 'application/json'}).
            to_return(:status => 200, :body => '[]')
      end

      it 'bails telling the user this command is only useful for the initial deployment' do
        expect { aws.bootstrap_bosh }.to raise_error(/Deployment `#{deployment_name}' already exists\./)
      end
    end

    context 'when the prerequisites are all met' do
      let(:username) { 'bosh_username' }
      let(:password) { 'bosh_password' }

      before do
        Bosh::Cli::PackageBuilder.any_instance.stub(:resolve_globs).and_return([])
        mock_s3.should_receive(:copy_remote_file).with('bosh-jenkins-artifacts','bosh-stemcell/aws/light-bosh-stemcell-latest-aws-xen-ubuntu-lucid-go_agent.tgz','bosh_stemcell.tgz').and_return(stemcell_stub)
        mock_s3.should_receive(:copy_remote_file).with('bosh-jenkins-artifacts', /release\/bosh-(.+)\.tgz/,'bosh_release.tgz').and_return('bosh_release.tgz')

        aws.config.target = aws.options[:target] = 'http://127.0.0.1:25555'
        aws.config.set_alias('target', '1234', 'http://127.0.0.1:25555')
        aws.config.save


        # FIXME This should be read from the bosh_config.yml file
        # but for some reason, auth is not being read properly
        aws.options[:username] = 'admin'
        aws.options[:password] = 'admin'

        # Verify deployment's existence
        stub_request(:get, 'http://127.0.0.1:25555/deployments').
            with(:headers => {'Content-Type' => 'application/json'}).
            to_return(:status => 200, :body => deployments.to_json)

        stub_request(:get, 'http://127.0.0.1:25555/releases').
            with(:headers => {'Content-Type' => 'application/json'}).
            to_return(
            {:status => 200, :body => '[]' },
            {:status => 200, :body => '[{"name" : "bosh", "release_versions" : [{"version" : "1"}]}]'}
        )

        stub_request(:get, %r{http://blob.cfblob.com/rest/objects}).
            to_return(:status => 200)

        stub_request(:post, %r{packages/matches}).
            to_return(:status => 200, :body => '[]')

        # Stub out the release creation to make the tests MUCH faster,
        # instead of actually building the tarball.
        Bosh::Cli::Command::Release::UploadRelease.any_instance.should_receive(:upload)

        stub_request(:get, 'http://127.0.0.1:25555/stemcells').
            to_return(:status => 200, :body => '[]').then.
            to_return(:status => 200, :body => '[]').then.
            to_return(:status => 200, :body => '[{"name":"bosh-stemcell","version":"2013-03-21_01-53-17","cid":"ami-1c990175"}]')

        @stemcell_upload_request = stub_request(:post, 'http://127.0.0.1:25555/stemcells').
            to_return(:status => 200, :body => '')

        # Checking for previous deployments properties from the receipt file.
        stub_request(:get, 'http://127.0.0.1:25555/deployments/vpc-bosh-dev102/properties').
            to_return(:status => 200, :body => '[]')

        # Checking for previous deployment manifest
        stub_request(:get, 'http://127.0.0.1:25555/deployments/vpc-bosh-dev102').
            to_return(:status => 200, :body => '{}')

        @deployment_request = stub_request(:post, 'http://127.0.0.1:25555/deployments').
            to_return(:status => 200, :body => '')

        new_target_info = {
            'uuid' => 'defg9876',
            'name' =>  deployment_name,
            'version' => '1234'
        }

        stub_request(:get, 'https://50.200.100.3:25555/info').
            with(:headers => {'Content-Type' => 'application/json'}).
            to_return(:status => 200, :body => new_target_info.to_json).
            to_return(:status => 200, :body => { 'user' => 'admin' }.to_json).
            to_return(:status => 200, :body => { 'user' => username}.to_json)

        aws.should_receive(:ask).with('Enter username: ').and_return(username)
        aws.should_receive(:ask).with('Enter password: ').and_return(password)

        SecureRandom.stub(:base64).and_return('hm_password')
        @create_hm_user_req = stub_request(:post, 'https://50.200.100.3:25555/users').
            with(body: {username: 'hm', password: 'hm_password'}).to_return(status: 204)

        @create_user_request = stub_request(:post, 'https://50.200.100.3:25555/users').
            with(:body => {username: username, password: password}.to_json).
            to_return(:status => 204, :body => new_target_info.to_json)
      end

      it 'generates an updated manifest for bosh' do
        File.exist?('deployments/bosh/bosh.yml').should be(false)
        aws.bootstrap_bosh
        File.exist?('deployments/bosh/bosh.yml').should be(true)
      end

      it 'runs deployment diff' do
        aws.bootstrap_bosh

        generated_manifest = File.read('deployments/bosh/bosh.yml')
        generated_manifest.should include('# Fake network properties to satisfy bosh diff')
      end

      it 'uploads the latest stemcell' do
        aws.bootstrap_bosh

        @stemcell_upload_request.should have_been_made
      end

      it 'deploys bosh' do
        aws.bootstrap_bosh

        @deployment_request.should have_been_made
      end

      it 'sets the target to the new bosh' do
        aws.bootstrap_bosh

        config_file = File.read(@bosh_config.path)
        config = Psych.load(config_file)
        config['target'].should == 'https://50.200.100.3:25555'
      end

      it 'creates a new user in new bosh' do
        aws.bootstrap_bosh

        credentials = encoded_credentials('admin', 'admin')
        a_request(:get, 'https://50.200.100.3:25555/info').with(
            :headers => {
                'Authorization' => "Basic #{credentials}",
                'Content-Type'=>'application/json'
            }).should have_been_made.once

        @create_user_request.should have_been_made

        credentials = encoded_credentials(username, password)
        a_request(:get, 'https://50.200.100.3:25555/info').with(
            :headers => {
                'Authorization' => "Basic #{credentials}",
                'Content-Type'=>'application/json'
            }).should have_been_made.once
      end

      it 'creates a new hm user in bosh' do
        aws.bootstrap_bosh
        @create_hm_user_req.should have_been_made.once
      end
    end
  end
end
