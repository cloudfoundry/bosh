require 'spec_helper'
require 'bosh/cli/commands/micro'

module Bosh::Cli::Command
  describe Micro do
    include FakeFS::SpecHelpers

    subject(:micro_command) { Micro.new(runner) }
    let(:runner) { double('Runner') }

    before { micro_command.stub(load_yaml_file: manifest_hash) }
    let(:manifest_hash) { { 'network' => 'something' } }

    before { FileUtils.mkdir_p(File.expand_path('~')) } # wat!

    before do
      FileUtils.mkdir_p('/tmp/foo')
      FileUtils.touch('/tmp/foo/micro_bosh.yml')
    end

    before do
      Bosh::Deployer::InstanceManager.stub(create: double(
        'Deployer',
        discover_bosh_ip: '5',
        check_dependencies: nil,
        exists?: false,
        :renderer= => nil,
        create_deployment: nil,
      ))
    end

    describe 'micro deployment' do
      before { Dir.chdir('/tmp') }

      context 'a relative path to a manifest is given' do
        before { FileUtils.touch('/tmp/foo/other_manifest.yml') }

        it 'sets the deployment location' do
          micro_command.micro_deployment('foo/other_manifest.yml')

          deployer_config_file = File.expand_path('~/.bosh_deployer_config')
          deployer_config = YAML.load_file(deployer_config_file)
          expect(deployer_config['deployment']).to eq(
            'https://5:25555' => '/tmp/foo/other_manifest.yml')
        end
      end

      context 'an absolute path to a manifest is given' do
        before { FileUtils.touch('/tmp/foo/other_manifest.yml') }

        it 'sets the deployment location' do
          micro_command.micro_deployment('/tmp/foo/other_manifest.yml')

          deployer_config_file = File.expand_path('~/.bosh_deployer_config')
          deployer_config = YAML.load_file(deployer_config_file)
          expect(deployer_config['deployment']).to eq(
            'https://5:25555' => '/tmp/foo/other_manifest.yml')
        end
      end

      context 'directory is given' do
        it 'can get and set the deployment location' do
          micro_command.micro_deployment('foo')

          deployer_config_file = File.expand_path('~/.bosh_deployer_config')
          deployer_config = YAML.load_file(deployer_config_file)
          expect(deployer_config['deployment']).to eq(
            'https://5:25555' => '/tmp/foo/micro_bosh.yml')
        end

        context 'non-existant manifest file specified' do
          let(:error_message) { "Missing manifest for bar (tried '/tmp/bar/micro_bosh.yml')" }

          before { FileUtils.mkdir_p('/tmp/bar/') }

          it 'errors' do
            expect {
              micro_command.micro_deployment('bar')
            }.to raise_error(Bosh::Cli::CliError, error_message)
          end
        end

        context 'manifest network is blank' do
          let(:error_message) { 'network is not defined in deployment manifest' }
          let(:manifest_hash) { { no_network: 'here' } }

          it 'errors' do
            expect {
              micro_command.micro_deployment('foo')
            }.to raise_error(Bosh::Cli::CliError, error_message)
          end
        end

        context 'manifest is not a hash' do
          let(:error_message) { 'Invalid manifest format' }
          let(:manifest_hash) { 'not actually a hash' }

          it 'errors' do
            expect {
              micro_command.micro_deployment('foo')
            }.to raise_error(Bosh::Cli::CliError, error_message)
          end
        end

        context 'target already exists' do
          context 'old director ip address is the same as new ip' do

            it 'does not change the configuration' do
              deployer_config_file = File.expand_path('~/.bosh_deployer_config')
              File.open(deployer_config_file, 'w') do |file|
                YAML.dump({
                  'target' => 'https://5:25555',
                  'target_name' => nil,
                  'target_version' => nil,
                  'target_uuid' => nil,
                  'deployment' => { 'https://5:25555' => '/tmp/foo/micro_bosh.yml' },
                }, file)
              end

              expect {
                micro_command.micro_deployment('foo')
              }.to_not change { YAML.load_file(deployer_config_file) }
            end
          end

          context 'new director has different ip address than previous director' do
            it 'changes the configuration' do
              deployer_config_file = File.expand_path('~/.bosh_deployer_config')
              File.open(deployer_config_file, 'w') do |file|
                YAML.dump({
                  'target' => 'https://10:25555',
                  'target_name' => nil,
                  'target_version' => nil,
                  'target_uuid' => nil,
                  'deployment' => { 'https://10:25555' => '/tmp/foo/micro_bosh.yml' },
                }, file)
              end

              expect {
                micro_command.micro_deployment('foo')
              }.to change { YAML.load_file(deployer_config_file) }
            end
          end
        end
      end

      context 'no deployment path is given' do
        context 'deployment is already set' do
          it 'says the current deployment' do
            deployer_config_file = File.expand_path('~/.bosh_deployer_config')
            File.open(deployer_config_file, 'w') do |file|
              YAML.dump({
                'target' => 'https://5:25555',
                'target_name' => nil,
                'target_version' => nil,
                'target_uuid' => nil,
                'deployment' => { 'https://5:25555' => '/tmp/foo/micro_bosh.yml' },
              }, file)
            end

            micro_command.should_receive(:say).with(
              "Current deployment is '/tmp/foo/micro_bosh.yml'")
            micro_command.micro_deployment
          end
        end

        context 'deployment is not set' do
          it 'says deployment is not set' do
            micro_command.should_receive(:say).with('Deployment not set')
            micro_command.micro_deployment
          end
        end
      end
    end

    describe 'perform' do
      confirmation =
        "\nNo `bosh-deployments.yml` file found in current directory." +
        "\n\nConventionally, `bosh-deployments.yml` should be saved in /tmp." +
        "\nIs /tmp/foo a directory where you can save state?"

      before do
        BoshExtensions.stub(:err)
        micro_command.stub(:confirmed?).and_return(true)
        micro_command.stub(:dig_hash).and_return(true)

        File.open(File.expand_path('~/.bosh_deployer_config'), 'w') do |file|
          YAML.dump({
            'target' => 'https://5:25555',
            'target_name' => nil,
            'target_version' => nil,
            'target_uuid' => nil,
            'deployment' => { 'https://5:25555' => '/tmp/foo/micro_bosh.yml' },
          }, file)
        end
      end

      context 'no `bosh-deployments.yml` file found in current directory' do
        context 'not in directory one level up from `micro_bosh.yml`' do
          it 'confirms that current directory is valid to save state' do
            micro_command.should_receive(:confirmed?).with(confirmation).and_return(true)
            Dir.chdir('/tmp/foo') { micro_command.perform('stemcell') }
          end
        end

        context 'not in directory one level up from `micro_bosh.yml`' do
          before { FileUtils.touch('/tmp/bosh-deployments.yml') }

          it 'does not add confirmation that current directory is valid to save state' do
            micro_command.should_not_receive(:confirmed?).with(confirmation)
            micro_command.perform('stemcell')
          end
        end
      end
    end
  end

  describe 'older tests' do
    before do
      @cmd = Bosh::Cli::Command::Micro.new(nil)
      @cmd.add_option(:non_interactive, true)
      @cmd.add_option(:config, nil)

      @manifest_path = spec_asset('deployment.MF')
      @manifest_yaml = {
        'name' => 'foo',
        'cloud' => {},
        'resources' => {
          'persistent_disk' => 16384,
          'cloud_properties' => {}
        },
      }
    end

    it 'allows deploying a micro BOSH instance passing stemcell as argument' do
      stemcell_archive = instance_double('Bosh::Stemcell::Archive')
      Bosh::Stemcell::Archive.should_receive(:new).and_return(stemcell_archive)

      mock_stemcell = double(Bosh::Cli::Stemcell)
      mock_stemcell.should_receive(:validate)
      mock_stemcell.should_receive(:valid?).and_return(true)
      Bosh::Cli::Stemcell.should_receive(:new).and_return(mock_stemcell)

      mock_deployer = double(Bosh::Deployer::InstanceManager)
      mock_deployer.should_receive(:exists?).exactly(2).times
      mock_deployer.should_receive(:renderer=)
      mock_deployer.should_receive(:check_dependencies)
      mock_deployer.should_receive(:create_deployment).with('stemcell.tgz', stemcell_archive)
      @cmd.stub(:deployer).and_return(mock_deployer)

      @cmd.stub(:deployment).and_return(@manifest_path)
      @cmd.stub(:load_yaml_file).and_return(@manifest_yaml)
      @cmd.stub(:target_name).and_return('micro-test')

      @cmd.perform('stemcell.tgz')
    end

    it 'allows deploying a micro BOSH instance passing stemcell in manifest file' do
      mock_deployer = double(Bosh::Deployer::InstanceManager)
      mock_deployer.should_receive(:exists?).exactly(2).times
      mock_deployer.should_receive(:renderer=)
      mock_deployer.should_receive(:check_dependencies)
      mock_deployer.should_receive(:create_deployment).with('sc-id', nil)

      @cmd.stub(:deployment).and_return(@manifest_path)
      @cmd.stub(:target_name).and_return('micro-test')
      @cmd.stub(:load_yaml_file).and_return(@manifest_yaml)
      @manifest_yaml['resources']['cloud_properties']['image_id'] = 'sc-id'
      @cmd.stub(:deployer).and_return(mock_deployer)
      @cmd.perform
    end

    it 'should not allow deploying a micro BOSH instance if no stemcell is provided' do
      expect {
        @cmd.stub(:deployment).and_return(@manifest_path)
        @manifest_yaml = { 'name' => 'foo' }
        @cmd.stub(:load_yaml_file).and_return(@manifest_yaml)
        @cmd.perform
      }.to raise_error(Bosh::Cli::CliError, 'No stemcell provided')
    end

    it 'should require a persistent disk' do
      file = Bosh::Cli::Command::Micro::MICRO_BOSH_YAML
      error_message = "No persistent disk configured in #{file}"
      expect {
        mock_deployer = double(Bosh::Deployer::InstanceManager)
        mock_deployer.should_receive(:check_dependencies)
        mock_deployer.should_receive(:exists?).exactly(1).times

        @cmd.stub(:deployment).and_return(@manifest_path)
        @cmd.stub(:target_name).and_return('micro-test')
        @cmd.stub(:load_yaml_file).and_return(@manifest_yaml)
        @manifest_yaml['resources']['cloud_properties']['image_id'] = 'sc-id'
        @manifest_yaml['resources']['persistent_disk'] = nil
        @cmd.stub(:deployer).and_return(mock_deployer)
        @cmd.perform
      }.to raise_error(Bosh::Cli::CliExit, error_message)
    end

    it 'should clear cached target values when setting a new deployment' do
      @cmd.stub(:find_deployment).with('foo').and_return(
        spec_asset('test-bootstrap-config-aws.yml'))
      @cmd.stub_chain(:deployer, :discover_bosh_ip).and_return(nil)

      config = double('config', target: 'target', resolve_alias: nil, set_deployment: nil)
      config.should_receive(:target=).with('https://foo:25555')
      config.should_receive(:target_name=).with(nil)
      config.should_receive(:target_version=).with(nil)
      config.should_receive(:target_uuid=).with(nil)
      config.should_receive(:save)

      @cmd.stub(:config).and_return(config)

      @cmd.set_current('foo')
    end

    describe 'agent command' do
      before { @cmd.stub(deployer: deployer) }
      let(:deployer) { double(Bosh::Deployer::InstanceManager, agent: agent) }
      let(:agent)    { double(Bosh::Agent::HTTPClient) }

      it 'sends the command to an agent and shows the returned output' do
        agent.should_receive(:ping).and_return('pong')
        @cmd.should_receive(:say) { |response| expect(response).to include('pong') }
        @cmd.agent('ping')
      end
    end

    describe 'deploying/updating with --update-if-exists flag' do
      let(:deployer) do
        double(
          Bosh::Deployer::InstanceManager,
          :renderer= => nil,
          :discover_bosh_ip => nil,
        )
      end

      before do
        deployer.stub(check_dependencies: true)
        @cmd.stub(deployer: deployer)
        @cmd.stub(deployment: @manifest_path)
        @cmd.stub(target_name: 'micro-test')
        @cmd.stub(load_yaml_file: @manifest_yaml)
        @cmd.stub(:update_target)
      end

      let(:tarball_path) { 'some-stemcell-path' }

      context 'when microbosh is not deployed' do
        before { deployer.stub(exists?: false) }

        context 'when --update-if-exists flag is given' do
          before { @cmd.add_option(:update_if_exists, true) }

          it 'creates microbosh and returns successfully' do
            deployer.should_receive(:create_deployment)
            @cmd.perform(tarball_path)
          end
        end

        context 'when --update-if-exists flag is not given' do
          it 'creates microbosh and returns successfully' do
            deployer.should_receive(:create_deployment)
            @cmd.perform(tarball_path)
          end
        end
      end

      context 'when microbosh is already deployed' do
        before { deployer.stub(exists?: true) }

        context 'when --update-if-exists flag is given' do
          before { @cmd.add_option(:update_if_exists, true) }

          it 'updates microbosh and returns successfully' do
            deployer.should_receive(:update_deployment)
            @cmd.perform(tarball_path)
          end
        end

        context 'when --update-if-exists flag is not given' do
          it 'does not update microbosh' do
            deployer.should_not_receive(:update_deployment)
            expect { @cmd.perform(tarball_path) }.to raise_error
          end

          it 'raises an error' do
            expect {
              @cmd.perform(tarball_path)
            }.to raise_error(Bosh::Cli::CliError, /Instance exists/)
          end
        end
      end
    end
  end
end
