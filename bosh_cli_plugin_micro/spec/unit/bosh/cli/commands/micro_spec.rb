require 'spec_helper'
require 'bosh/cli/commands/micro'

module Bosh::Cli::Command
  describe Micro do
    include FakeFS::SpecHelpers

    let(:runner) { double('Runner') }
    let(:manifest_hash) { { 'network' => 'something' } }
    subject(:micro_command) { Micro.new(runner) }

    describe 'micro deployment' do
      before do
        FileUtils.mkdir_p('/tmp/foo/')
        FileUtils.mkdir_p(File.expand_path('~'))
        FileUtils.touch('/tmp/foo/micro_bosh.yml')
        Dir.chdir('/tmp')
        micro_command.stub(:load_yaml_file).and_return(manifest_hash)

        Bosh::Deployer::InstanceManager.stub(create: double('Deployer', discover_bosh_ip: '5'))
      end

      context 'the full path to a manifest is given' do
        before do
          FileUtils.touch('/tmp/foo/other_manifest.yml')
        end

        it 'sets the deployment location' do
          micro_command.micro_deployment('foo/other_manifest.yml')

          deployer_config_file = File.expand_path('~/.bosh_deployer_config')
          deployer_config = YAML.load_file(deployer_config_file)
          expect(deployer_config['deployment']).to eq('https://5:25555' => '/tmp/foo/other_manifest.yml')
        end
      end

      context 'name is given' do
        it 'can get and set the deployment location' do
          micro_command.micro_deployment('foo')

          deployer_config_file = File.expand_path('~/.bosh_deployer_config')
          deployer_config = YAML.load_file(deployer_config_file)
          expect(deployer_config['deployment']).to eq('https://5:25555' => '/tmp/foo/micro_bosh.yml')
        end

        context 'non-existant manifest file specified' do
          let(:error_message) { "Missing manifest for bar (tried '/tmp/bar/micro_bosh.yml')" }

          before do
            FileUtils.mkdir_p('/tmp/bar/')
          end

          it 'errors' do
            expect { micro_command.micro_deployment('bar') }.to raise_error(Bosh::Cli::CliError, error_message)
          end
        end

        context 'manifest network is blank' do
          let(:error_message) { "network is not defined in deployment manifest" }
          let(:manifest_hash) { { no_network: 'here' } }

          it 'errors' do
            expect { micro_command.micro_deployment('foo') }.to raise_error(Bosh::Cli::CliError, error_message)
          end
        end

        context 'manifest is not a hash' do
          let(:error_message) { "Invalid manifest format" }
          let(:manifest_hash) { 'not actually a hash' }

          it 'errors' do
            expect { micro_command.micro_deployment('foo') }.to raise_error(Bosh::Cli::CliError, error_message)
          end
        end

        context 'target already exists' do
          context 'old director ip address is the same as new ip' do

            it 'does not change the configuration' do
              #micro_command.micro_deployment('foo')

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

              expect { micro_command.micro_deployment('foo') }.to_not change { YAML.load_file(deployer_config_file) }
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

              expect { micro_command.micro_deployment('foo') }.to change { YAML.load_file(deployer_config_file) }
            end
          end
        end
      end

      context 'name is not given' do
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
  end
end