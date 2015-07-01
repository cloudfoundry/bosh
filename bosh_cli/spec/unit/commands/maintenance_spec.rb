require 'spec_helper'

describe Bosh::Cli::Command::Maintenance do
  let(:command) { described_class.new }
  let(:director) { double(Bosh::Cli::Client::Director) }

  before do
    allow(command).to receive(:director).and_return(director)
    command.options[:non_interactive] = true
    command.options[:username] = 'admin'
    command.options[:password] = 'admin'
    target = 'https://127.0.0.1:8080'
    command.options[:target] = target
    stub_request(:get, "#{target}/info").to_return(body: '{}')

    allow(director).to receive(:list_stemcells).and_return([])
  end

  describe 'cleanup' do
    describe 'stemcells' do
      before do
        stemcells = [
            {
                'name' => 'bosh-aws-xen-ubuntu',
                'version' => '1471.2',
                'cid' => 'fake-ami-1 light',
                'deployments' => []
            },
            {
                'name' => 'bosh-aws-xen-ubuntu',
                'version' => '2555',
                'cid' => 'fake-ami-2 light',
                'deployments' => ['fake-deployment']
            },
            {
                'name' => 'bosh-aws-xen-ubuntu',
                'version' => '2579',
                'cid' => 'fake-ami-3 light',
                'deployments' => []
            },
            {
                'name' => 'bosh-aws-xen-ubuntu',
                'version' => '2578',
                'cid' => 'fake-ami-4 light',
                'deployments' => []
            },
            {
              'name' => 'bosh-aws-xen-centos',
              'version' => '3578',
              'cid' => 'fake-ami-4 light',
              'deployments' => []
            }
        ]
        allow(director).to receive(:list_stemcells).and_return(stemcells)
        allow(director).to receive(:list_releases).and_return([])
      end

      context 'when --all flag is passed' do
        before { command.options[:all] = true }

        it 'removes all unused stemcells and properly pick out stemcells to delete' do
          expect(director).to receive(:delete_stemcell).with('bosh-aws-xen-ubuntu', '1471.2', quiet: true)
          expect(director).to receive(:delete_stemcell).with('bosh-aws-xen-ubuntu', '2579', quiet: true)
          expect(director).to receive(:delete_stemcell).with('bosh-aws-xen-ubuntu', '2578', quiet: true)
          expect(director).to receive(:delete_stemcell).with('bosh-aws-xen-centos', '3578', quiet: true)
          command.cleanup
        end
      end

      context 'when no flags are passed' do
        it 'removes stemcells excepts last 2 and the used one' do
          expect(director).to receive(:delete_stemcell).with('bosh-aws-xen-ubuntu', '1471.2', quiet: true)
          command.cleanup
        end
      end
    end

    describe 'releases' do
      context 'old releases format' do
        let(:release) do
          {
              'name' => 'release-1',
              'versions' => ['15', '2', '1', '8.1-dev', '8.2-dev', '8.3-dev'],
              'in_use' => ['8.3-dev']
          }
        end

        context 'when --all flag is passed' do
          before { command.options[:all] = true }

          it 'should cleanup all unused releases' do
            allow(director).to receive(:list_releases).and_return([release])

            expect(director).to receive(:delete_release).
                                    with('release-1', force: false, version: '1', quiet: true).
                                    and_return([:done, 1])
            expect(director).to receive(:delete_release).
                                    with('release-1', force: false, version: '2', quiet: true).
                                    and_return([:done, 2])
            expect(director).to receive(:delete_release).
                                    with('release-1', force: false, version: '8.1-dev', quiet: true).
                                    and_return([:done, 2])
            expect(director).to receive(:delete_release).
                                    with('release-1', force: false, version: '8.2-dev', quiet: true).
                                    and_return([:done, 2])
            expect(director).to receive(:delete_release).
                                    with('release-1', force: false, version: '15', quiet: true).
                                    and_return([:done, 2])

            command.cleanup
          end
        end

        context 'when no flag is passed' do
          it 'should cleanup unused releases, making sure to leave the two most recent' do
            allow(director).to receive(:list_releases).and_return([release])

            expect(director).to receive(:delete_release).
                                    with('release-1', force: false, version: '1', quiet: true).
                                    and_return([:done, 1])
            expect(director).to receive(:delete_release).
                                    with('release-1', force: false, version: '2', quiet: true).
                                    and_return([:done, 2])
            expect(director).to receive(:delete_release).
                                    with('release-1', force: false, version: '8.1-dev', quiet: true).
                                    and_return([:done, 2])
            expect(director).to receive(:delete_release).
                                    with('release-1', force: false, version: '8.2-dev', quiet: true).
                                    and_return([:done, 2])

            command.cleanup
          end
        end
      end

      context 'new releases format' do
        let(:release) do
          {
              'name' => 'release-1',
              'release_versions' => [
                  {'version' => '15', 'commit_hash' => '1a2b3c4d', 'uncommitted_changes' => true, 'currently_deployed' => false},
                  {'version' => '2', 'commit_hash' => '00000000', 'uncommitted_changes' => true, 'currently_deployed' => false},
                  {'version' => '1', 'commit_hash' => 'unknown', 'uncommitted_changes' => false, 'currently_deployed' => false},
                  {'version' => '8.1-dev', 'commit_hash' => 'unknown', 'uncommitted_changes' => false, 'currently_deployed' => false},
                  {'version' => '8.2-dev', 'commit_hash' => 'unknown', 'uncommitted_changes' => false, 'currently_deployed' => true},
                  {'version' => '8.3-dev', 'commit_hash' => 'unknown', 'uncommitted_changes' => false, 'currently_deployed' => false},
              ]
          }
        end

        context 'when --all flag is passed' do
          it 'should cleanup all unused releases' do
            allow(director).to receive(:list_releases).and_return([release])

            expect(director).to receive(:delete_release).
                                    with('release-1', force: false, version: '1', quiet: true).
                                    and_return([:done, 1])
            expect(director).to receive(:delete_release).
                                    with('release-1', force: false, version: '2', quiet: true).
                                    and_return([:done, 2])
            expect(director).to receive(:delete_release).
                                    with('release-1', force: false, version: '8.1-dev', quiet: true).
                                    and_return([:done, 2])

            command.cleanup
          end
        end

        context 'when no flag is passed' do
          it 'should cleanup unused releases, making sure to leave the two most recent' do
            allow(director).to receive(:list_releases).and_return([release])

            expect(director).to receive(:delete_release).
                                    with('release-1', force: false, version: '1', quiet: true).
                                    and_return([:done, 1])
            expect(director).to receive(:delete_release).
                                    with('release-1', force: false, version: '2', quiet: true).
                                    and_return([:done, 2])
            expect(director).to receive(:delete_release).
                                    with('release-1', force: false, version: '8.1-dev', quiet: true).
                                    and_return([:done, 2])

            command.cleanup
          end
        end
      end
    end
  end
end
