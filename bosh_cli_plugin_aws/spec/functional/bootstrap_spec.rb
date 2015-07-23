require 'spec_helper'

describe 'AWS Bootstrap commands' do
  let(:aws) { Bosh::Cli::Command::AWS.new }
  let(:mock_s3) { double(Bosh::AwsCliPlugin::S3) }
  let(:bosh_config)  { File.expand_path(File.join(File.dirname(__FILE__), '..', 'assets', 'bosh_config.yml')) }

  before do
    aws.options[:non_interactive] = true

    WebMock.disable_net_connect!
    allow(aws).to receive(:sleep)
    allow(aws).to receive(:s3).and_return(mock_s3)
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
      let(:user_command) { double('Command User') }
      let(:login_command) { double('Command Login') }

      before do
        allow(Bosh::Cli::Command::User).to receive(:new).and_return(user_command)
        allow(Bosh::Cli::Command::Login).to receive(:new).and_return(login_command)
        allow(user_command).to receive(:options=)
        allow(login_command).to receive(:options=)
      end

      it 'should bootstrap microbosh' do
        stemcell_ami_request = stub_request(:get, 'http://bosh-jenkins-artifacts.s3.amazonaws.com/last_successful-bosh-stemcell-aws_ami_us-east-1').
            to_return(:status => 200, :body => 'ami-0e3da467', :headers => {})

        expect(SecureRandom).to receive(:base64).and_return('hm_password')
        expect(SecureRandom).to receive(:base64).and_return('admin_password')

        expect(login_command).to receive(:login).with('admin', 'admin')
        expect(user_command).to receive(:create).with('admin', 'admin_password').and_return(true)
        expect(login_command).to receive(:login).with('admin', 'admin_password')
        expect(user_command).to receive(:create).with('hm', 'hm_password').and_return(true)
        expect(login_command).to receive(:login).with('hm', 'hm_password')

        expect_any_instance_of(Bosh::Deployer::InstanceManager).to receive(:with_lifecycle)

        aws.bootstrap_micro

        expect(stemcell_ami_request).to have_been_made
      end

      context 'hm user and password' do
        let(:fake_bootstrap) { double('MicroBosh Bootstrap', start: true) }
        before do
          allow(Bosh::AwsCliPlugin::MicroBoshBootstrap).to receive(:new).and_return(fake_bootstrap)
        end

        it "creates default 'hm' user name for hm" do
          allow(fake_bootstrap).to receive(:create_user)

          expect(fake_bootstrap).to receive(:create_user).with('hm', anything)
          aws.bootstrap_micro
        end

        it 'passes the generated hm user to the new microbosh bootstrapper' do
          allow(SecureRandom).to receive(:base64).and_return('some_password')
          allow(fake_bootstrap).to receive(:create_user)
          expect(Bosh::AwsCliPlugin::MicroBoshBootstrap).to receive(:new) do |_, options|
            expect(options[:hm_director_user]).to eq('hm')
            expect(options[:hm_director_password]).to eq('some_password')
            fake_bootstrap
          end
          aws.bootstrap_micro
        end

        it 'creates a hm user with name from options' do
          aws.options[:hm_director_user] = 'hm_guy'
          allow(fake_bootstrap).to receive(:create_user)
          expect(fake_bootstrap).to receive(:create_user).with('hm_guy', anything)
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
        allow(Bosh::AwsCliPlugin::MicroBoshBootstrap).to receive(:new).and_return(fake_bootstrap)

        expect(aws).to receive(:ask).with('Enter username: ').and_return('admin')
        expect(aws).to receive(:ask).with('Enter password: ').and_return('admin_passwd')
        expect(fake_bootstrap).to receive(:create_user).with('admin', 'admin_passwd')
        expect(fake_bootstrap).to receive(:create_user).with('hm', anything)

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
        aws.config.target = aws.options[:target] = 'http://127.0.0.1:25555'

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
        allow_any_instance_of(Bosh::AwsCliPlugin::BoshBootstrap).to receive(:deploy)
        allow_any_instance_of(Bosh::AwsCliPlugin::BoshBootstrap).to receive(:target_bosh_and_log_in)
        allow_any_instance_of(Bosh::AwsCliPlugin::BoshBootstrap).to receive(:create_user)
        allow_any_instance_of(Bosh::Cli::Command::AWS).to receive(:ask).and_return('foo')

      end

      it 'use the existent release' do
        expect(mock_s3).not_to receive(:copy_remote_file)
        expect(Bosh::Exec).not_to receive(:sh).with('bundle exec rake release:create_dev_release')
        expect_any_instance_of(Bosh::Cli::Command::Release::UploadRelease).not_to receive(:upload)

        expect do
          aws.bootstrap_bosh
        end.to_not raise_error
      end

      it 'use the existent stemcell' do
        expect(mock_s3).not_to receive(:copy_remote_file)
        expect_any_instance_of(Bosh::Cli::Command::Stemcell).not_to receive(:upload)
        expect do
          aws.bootstrap_bosh
        end.to_not raise_error
      end

      context 'when the target has no stemcell' do
        let(:stemcell_archive) { instance_double('Bosh::Stemcell::Archive', name: 'bosh-stemcell-ubuntu')}
        it 'uploads a stemcell' do
          stub_request(:get, 'http://127.0.0.1:25555/stemcells').
            to_return(status: 200, body: '[]')
          expect(mock_s3).to receive(:copy_remote_file).and_return '/tmp/bosh_stemcell.tgz'
          expect(Bosh::Stemcell::Archive).to receive(:new).with('/tmp/bosh_stemcell.tgz').and_return(stemcell_archive)
          expect_any_instance_of(Bosh::Cli::Command::Stemcell).to receive(:upload)
          aws.bootstrap_bosh
        end
      end
    end

    context 'when the target already have a deployment' do
      # This deployment name comes from test-output.yml asset file.
      let(:deployment_name) { 'vpc-bosh-dev102' }

      before do
        aws.options[:target] = 'http://127.0.0.1:25555'

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
        allow_any_instance_of(Bosh::Cli::Resources::Package).to receive(:resolve_globs).and_return([])
        expect(mock_s3).to receive(:copy_remote_file).with('bosh-jenkins-artifacts','bosh-stemcell/aws/light-bosh-stemcell-latest-aws-xen-ubuntu-trusty-go_agent.tgz','bosh_stemcell.tgz').and_return(stemcell_stub)
        expect(mock_s3).to receive(:copy_remote_file).with('bosh-jenkins-artifacts', /release\/bosh-(.+)\.tgz/,'bosh_release.tgz').and_return('bosh_release.tgz')

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
        expect_any_instance_of(Bosh::Cli::Command::Release::UploadRelease).to receive(:upload)

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

        expect(aws).to receive(:ask).with('Enter username: ').and_return(username)
        expect(aws).to receive(:ask).with('Enter password: ').and_return(password)

        allow(SecureRandom).to receive(:base64).and_return('hm_password')
        @create_hm_user_req = stub_request(:post, 'https://50.200.100.3:25555/users').
            with(body: {username: 'hm', password: 'hm_password'}).to_return(status: 204)

        @create_user_request = stub_request(:post, 'https://50.200.100.3:25555/users').
            with(:body => {username: username, password: password}.to_json).
            to_return(:status => 204, :body => new_target_info.to_json)
      end

      it 'generates an updated manifest for bosh' do
        expect(File.exist?('deployments/bosh/bosh.yml')).to be(false)
        aws.bootstrap_bosh
        expect(File.exist?('deployments/bosh/bosh.yml')).to be(true)
      end

      it 'runs deployment diff' do
        aws.bootstrap_bosh

        generated_manifest = File.read('deployments/bosh/bosh.yml')
        expect(generated_manifest).to include('# Fake network properties to satisfy bosh diff')
      end

      it 'uploads the latest stemcell' do
        aws.bootstrap_bosh

        expect(@stemcell_upload_request).to have_been_made
      end

      it 'deploys bosh' do
        aws.bootstrap_bosh

        expect(@deployment_request).to have_been_made
      end

      it 'sets the target to the new bosh' do
        aws.bootstrap_bosh

        config_file = File.read(@bosh_config.path)
        config = Psych.load(config_file)
        expect(config['target']).to eq('https://50.200.100.3:25555')
      end

      it 'creates a new user in new bosh' do
        aws.bootstrap_bosh

        credentials = encoded_credentials('admin', 'admin')
        expect(a_request(:get, 'https://50.200.100.3:25555/info').with(
            :headers => {
                'Authorization' => "Basic #{credentials}",
                'Content-Type'=>'application/json'
            })).to have_been_made.times(4)

        expect(@create_user_request).to have_been_made

        credentials = encoded_credentials(username, password)
        expect(a_request(:get, 'https://50.200.100.3:25555/info').with(
            :headers => {
                'Authorization' => "Basic #{credentials}",
                'Content-Type'=>'application/json'
            })).to have_been_made.once
      end

      it 'creates a new hm user in bosh' do
        aws.bootstrap_bosh
        expect(@create_hm_user_req).to have_been_made.once
      end
    end
  end
end
