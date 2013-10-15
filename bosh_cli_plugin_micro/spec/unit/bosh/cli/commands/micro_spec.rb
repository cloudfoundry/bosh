require 'spec_helper'
require 'bosh/cli/commands/micro'

module Bosh::Cli::Command
  describe Micro do
    include FakeFS::SpecHelpers

    let(:runner) { double('Runner') }
    let(:manifest_hash) { {'network' => 'something'} }
    subject(:micro_command) { Micro.new(runner) }

    before do
      FileUtils.mkdir_p('/tmp/foo/')
      FileUtils.mkdir_p(File.expand_path('~'))
      FileUtils.touch('/tmp/foo/micro_bosh.yml')
      Dir.chdir('/tmp')
      micro_command.stub(:load_yaml_file).and_return(manifest_hash)

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
      context 'a relative path to a manifest is given' do
        before { FileUtils.touch('/tmp/foo/other_manifest.yml') }

        it 'sets the deployment location' do
          micro_command.micro_deployment('foo/other_manifest.yml')

          deployer_config_file = File.expand_path('~/.bosh_deployer_config')
          deployer_config = YAML.load_file(deployer_config_file)
          expect(deployer_config['deployment']).to eq('https://5:25555' => '/tmp/foo/other_manifest.yml')
        end
      end

      context 'an absolute path to a manifest is given' do
        before { FileUtils.touch('/tmp/foo/other_manifest.yml') }

        it 'sets the deployment location' do
          micro_command.micro_deployment('/tmp/foo/other_manifest.yml')

          deployer_config_file = File.expand_path('~/.bosh_deployer_config')
          deployer_config = YAML.load_file(deployer_config_file)
          expect(deployer_config['deployment']).to eq('https://5:25555' => '/tmp/foo/other_manifest.yml')
        end
      end

      context 'directory is given' do
        it 'can get and set the deployment location' do
          micro_command.micro_deployment('foo')

          deployer_config_file = File.expand_path('~/.bosh_deployer_config')
          deployer_config = YAML.load_file(deployer_config_file)
          expect(deployer_config['deployment']).to eq('https://5:25555' => '/tmp/foo/micro_bosh.yml')
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
          let(:error_message) { "network is not defined in deployment manifest" }
          let(:manifest_hash) { {no_network: 'here'} }

          it 'errors' do
            expect {
              micro_command.micro_deployment('foo')
            }.to raise_error(Bosh::Cli::CliError, error_message)
          end
        end

        context 'manifest is not a hash' do
          let(:error_message) { "Invalid manifest format" }
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
                  'deployment' => {'https://5:25555' => '/tmp/foo/micro_bosh.yml'},
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
                  'deployment' => {'https://10:25555' => '/tmp/foo/micro_bosh.yml'},
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
                'deployment' => {'https://5:25555' => '/tmp/foo/micro_bosh.yml'},
              }, file)
            end

            micro_command.should_receive(:say).with("Current deployment is '/tmp/foo/micro_bosh.yml'")
            micro_command.micro_deployment
          end
        end

        context 'deployment is not set' do
          it 'says deployment is not set' do
            micro_command.should_receive(:say).with("Deployment not set")
            micro_command.micro_deployment
          end
        end
      end
    end

    describe 'perform' do
      let(:confirmation) do
        "\nNo `bosh-deployments.yml` file found in current directory." +
        "\n\nConventionally, `bosh-deployments.yml` should be saved in /tmp." +
        "\nIs /tmp/foo a directory where you can save state?"
      end

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
            'deployment' => {'https://5:25555' => '/tmp/foo/micro_bosh.yml'},
          }, file)
        end
      end

      context 'no `bosh-deployments.yml` file found in current directory' do
        context 'not in directory one level up from `micro_bosh.yml`' do
          it 'confirms that current directory is valid to save state' do
            micro_command.should_receive(:confirmed?).with(confirmation).and_return(true)
            Dir.chdir('foo') { micro_command.perform('stemcell') }
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
end
