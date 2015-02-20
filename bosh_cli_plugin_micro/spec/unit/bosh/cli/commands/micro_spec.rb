require 'spec_helper'
require 'bosh/deployer/instance_manager'
require 'bosh/cli/commands/micro'

module Bosh::Cli::Command
  describe Micro do
    include FakeFS::SpecHelpers

    subject(:micro_command) { Micro.new(runner) }
    let(:runner) { double('Runner') }

    before { allow(micro_command).to receive_messages(load_yaml_file: manifest_hash) }
    let(:manifest_hash) { { 'network' => 'something' } }

    before { FileUtils.mkdir_p(File.expand_path('~')) } # wat!

    before do
      FileUtils.mkdir_p('/tmp/foo')
      FileUtils.touch('/tmp/foo/micro_bosh.yml')
    end

    let(:deployer) { instance_double('Bosh::Deployer::InstanceManager') }
    before do
      allow(deployer).to receive(:client_services_ip).and_return('5')
      allow(deployer).to receive(:check_dependencies).and_return(nil)
      allow(deployer).to receive(:exists?).and_return(false)
      allow(deployer).to receive(:renderer).and_return(nil)
      allow(deployer).to receive(:create_deployment).and_return(nil)
      allow(Bosh::Deployer::InstanceManager).to receive_messages(create: deployer)
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

        context 'target does not already exist' do
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

            expect(micro_command).to receive(:say).with(
              "Current deployment is '/tmp/foo/micro_bosh.yml'")
            micro_command.micro_deployment
          end
        end

        context 'deployment is not set' do
          it 'says deployment is not set' do
            expect(micro_command).to receive(:say).with('Deployment not set')
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

      let(:config) { double('config', target: 'target', resolve_alias: nil, set_deployment: nil) }

      before do
        allow(BoshExtensions).to receive(:err)
        allow(micro_command).to receive(:confirmed?).and_return(true)
        allow(micro_command).to receive(:dig_hash).and_return(true)

        File.open(File.expand_path('~/.bosh_deployer_config'), 'w') do |file|
          YAML.dump({
                      'target' => 'https://5:25555',
                      'target_name' => nil,
                      'target_version' => nil,
                      'target_uuid' => nil,
                      'deployment' => { 'https://5:25555' => '/tmp/foo/micro_bosh.yml' },
                    }, file)
        end

        allow(deployer).to receive(:renderer=)

        allow(config).to receive(:target=)
        allow(config).to receive(:target_name=)
        allow(config).to receive(:target_version=)
        allow(config).to receive(:target_uuid=)
        allow(config).to receive(:save)
        allow(config).to receive(:deployment).and_return('/tmp/foo/micro_bosh.yml')
        allow(config).to receive(:target_name).and_return('fake-name')
        allow(micro_command).to receive(:config).and_return(config)
      end

      context 'no `bosh-deployments.yml` file found in current directory' do
        context 'not in directory one level up from `micro_bosh.yml`' do
          it 'confirms that current directory is valid to save state' do
            expect(micro_command).to receive(:confirmed?).with(confirmation).and_return(true)
            Dir.chdir('/tmp/foo') { micro_command.perform('stemcell') }
          end
        end

        context 'not in directory one level up from `micro_bosh.yml`' do
          before { FileUtils.touch('/tmp/bosh-deployments.yml') }

          it 'does not add confirmation that current directory is valid to save state' do
            expect(micro_command).not_to receive(:confirmed?).with(confirmation)
            micro_command.perform('stemcell')
          end
        end
      end

      context 'when microbosh is successfully deployed' do
        before do
          allow(deployer).to receive(:exists?).and_return(false, true)
        end

        it 'updates the bosh target to the deployment' do
          expect(config).to receive(:target=).with('https://5:25555')
          expect(config).to receive(:target_name=).with('Unknown Director')
          expect(config).to receive(:target_version=).with('n/a')
          expect(config).to receive(:target_uuid=).with(nil)
          expect(config).to receive(:save)

          micro_command.perform('stemcell')
        end

        context 'with the director_checks option' do
          let(:director) { instance_double('Bosh::Cli::Client::Director') }

          before do
            micro_command.add_option(:director_checks, true)

            class_double('Bosh::Cli::Client::Director').as_stubbed_const
            allow(Bosh::Cli::Client::Director).to receive(:new).and_return(director)
          end

          context 'when the director returns the status successfully' do
            before do
              allow(director).to receive(:get_status).and_return(
                                   'name' => 'our director',
                                   'version' => 'some version',
                                   'uuid' => 'abc'
                                 )
            end

            it 'updates the bosh target with the director status' do
              expect(config).to receive(:target=).with('https://5:25555')
              expect(config).to receive(:target_name=).with('our director')
              expect(config).to receive(:target_version=).with('some version')
              expect(config).to receive(:target_uuid=).with('abc')
              expect(config).to receive(:save)

              micro_command.perform('stemcell')
            end
          end
        end
      end

      context 'when microbosh is not successfully deployed' do
        before do
          allow(deployer).to receive(:exists?).and_return(false)
        end

        it 'updates the bosh target to the deployment' do
          expect(config).to receive(:target=).with('https://5:25555')
          expect(config).to receive(:target_name=).with(nil).twice
          expect(config).to receive(:target_version=).with(nil).twice
          expect(config).to receive(:target_uuid=).with(nil).twice
          expect(config).to receive(:save)

          micro_command.perform('stemcell')
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
        'network' => {},
        'cloud' => {},
        'resources' => {
          'persistent_disk' => 16384,
          'cloud_properties' => {}
        },
      }
    end

    it 'allows deploying a micro BOSH instance passing stemcell as argument' do
      stemcell_archive = instance_double('Bosh::Stemcell::Archive')
      expect(Bosh::Stemcell::Archive).to receive(:new).and_return(stemcell_archive)

      mock_stemcell = double(Bosh::Cli::Stemcell)
      expect(mock_stemcell).to receive(:validate)
      expect(mock_stemcell).to receive(:valid?).and_return(true)
      expect(Bosh::Cli::Stemcell).to receive(:new).and_return(mock_stemcell)

      mock_deployer = double(Bosh::Deployer::InstanceManager, client_services_ip: '5')
      expect(mock_deployer).to receive(:exists?).exactly(2).times
      expect(mock_deployer).to receive(:renderer=)
      expect(mock_deployer).to receive(:check_dependencies)
      expect(mock_deployer).to receive(:create_deployment).with('stemcell.tgz', stemcell_archive)
      allow(@cmd).to receive(:deployer).and_return(mock_deployer)

      allow(@cmd).to receive(:deployment).and_return(@manifest_path)
      allow(@cmd).to receive(:load_yaml_file).and_return(@manifest_yaml)
      allow(@cmd).to receive(:target_name).and_return('micro-test')

      @cmd.perform('stemcell.tgz')
    end

    it 'allows deploying a micro BOSH instance passing stemcell in manifest file' do
      mock_deployer = double(Bosh::Deployer::InstanceManager, client_services_ip: '5')
      expect(mock_deployer).to receive(:exists?).exactly(2).times
      expect(mock_deployer).to receive(:renderer=)
      expect(mock_deployer).to receive(:check_dependencies)
      expect(mock_deployer).to receive(:create_deployment).with('sc-id', nil)

      allow(@cmd).to receive(:deployment).and_return(@manifest_path)
      allow(@cmd).to receive(:target_name).and_return('micro-test')
      allow(@cmd).to receive(:load_yaml_file).and_return(@manifest_yaml)
      @manifest_yaml['resources']['cloud_properties']['image_id'] = 'sc-id'
      allow(@cmd).to receive(:deployer).and_return(mock_deployer)
      @cmd.perform
    end

    it 'should not allow deploying a micro BOSH instance if no stemcell is provided' do
      expect {
        allow(@cmd).to receive(:deployment).and_return(@manifest_path)
        @manifest_yaml = { 'name' => 'foo' }
        allow(@cmd).to receive(:load_yaml_file).and_return(@manifest_yaml)
        @cmd.perform
      }.to raise_error(Bosh::Cli::CliError, 'No stemcell provided')
    end

    it 'should require a persistent disk' do
      file = Bosh::Cli::Command::Micro::MICRO_BOSH_YAML
      error_message = "No persistent disk configured in #{file}"
      expect {
        mock_deployer = double(Bosh::Deployer::InstanceManager)
        expect(mock_deployer).to receive(:check_dependencies)
        expect(mock_deployer).to receive(:exists?).exactly(1).times

        allow(@cmd).to receive(:deployment).and_return(@manifest_path)
        allow(@cmd).to receive(:target_name).and_return('micro-test')
        allow(@cmd).to receive(:load_yaml_file).and_return(@manifest_yaml)
        @manifest_yaml['resources']['cloud_properties']['image_id'] = 'sc-id'
        @manifest_yaml['resources']['persistent_disk'] = nil
        allow(@cmd).to receive(:deployer).and_return(mock_deployer)
        @cmd.perform
      }.to raise_error(Bosh::Cli::CliExit, error_message)
    end

    it 'should clear cached target values when setting a new deployment' do
      allow(@cmd).to receive(:find_deployment).with('foo').and_return(
        spec_asset('test-bootstrap-config-aws.yml'))
      allow(@cmd).to receive_message_chain(:deployer, :client_services_ip).and_return('client_ip')

      config = double('config', target: 'target', resolve_alias: nil, set_deployment: nil)
      expect(config).to receive(:target=).with('https://client_ip:25555')
      expect(config).to receive(:target_name=).with(nil)
      expect(config).to receive(:target_version=).with(nil)
      expect(config).to receive(:target_uuid=).with(nil)
      expect(config).to receive(:save)

      allow(@cmd).to receive(:config).and_return(config)

      @cmd.set_current('foo')
    end

    describe 'agent command' do
      before { allow(@cmd).to receive_messages(deployer: deployer) }
      let(:deployer) { double(Bosh::Deployer::InstanceManager, agent: agent) }
      let(:agent) { double(Bosh::Agent::HTTPClient) }

      it 'sends the command to an agent and shows the returned output' do
        expect(agent).to receive(:ping).and_return('pong')
        expect(@cmd).to receive(:say) { |response| expect(response).to include('pong') }
        @cmd.agent('ping')
      end
    end

    describe 'deploying/updating with --update-if-exists flag' do
      let(:deployer) do
        double(
          Bosh::Deployer::InstanceManager,
          :renderer= => nil,
          :client_services_ip => 'client_ip'
        )
      end

      before do
        allow(deployer).to receive_messages(check_dependencies: true)
        allow(@cmd).to receive_messages(deployer: deployer)
        allow(@cmd).to receive_messages(deployment: @manifest_path)
        allow(@cmd).to receive_messages(target_name: 'micro-test')
        allow(@cmd).to receive_messages(load_yaml_file: @manifest_yaml)
        allow(@cmd.config).to receive(:save)
      end

      let(:tarball_path) { 'some-stemcell-path' }

      context 'when microbosh is not deployed' do
        before { allow(deployer).to receive(:exists?).and_return(false) }

        context 'when --update-if-exists flag is given' do
          before { @cmd.add_option(:update_if_exists, true) }

          it 'creates microbosh and returns successfully' do
            expect(deployer).to receive(:create_deployment)
            @cmd.perform(tarball_path)
          end
        end

        context 'when --update-if-exists flag is not given' do
          it 'creates microbosh and returns successfully' do
            expect(deployer).to receive(:create_deployment)
            @cmd.perform(tarball_path)
          end
        end
      end

      context 'when microbosh is already deployed' do
        before { allow(deployer).to receive_messages(exists?: true) }

        context 'when --update-if-exists flag is given' do
          before { @cmd.add_option(:update_if_exists, true) }
          it 'updates microbosh and returns successfully' do

            expect(deployer).to receive(:update_deployment)
            @cmd.perform(tarball_path)
          end
        end

        context 'when --update-if-exists flag is not given' do
          it 'does not update microbosh' do
            expect(deployer).not_to receive(:update_deployment)
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
