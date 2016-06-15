require 'spec_helper'

describe Bosh::Cli::Manifest do
  include FakeFS::SpecHelpers

  subject(:manifest) do
    deployment_file = 'fake-deployment-file'
    File.open(deployment_file, 'w') { |f| f.write(YAML.dump(manifest_data)) }
    Bosh::Cli::Manifest.new(deployment_file, director)
  end

  before { manifest.load }

  let(:manifest_data) { {} }
  let(:director) { instance_double('Bosh::Cli::Client::Director') }

  let(:release_list) do
    [
      {
        'name' => 'bat',
        'release_versions' => [
          {
            'version' => '1',
            'commit_hash' => 'unknown',
            'uncommitted_changes' => false,
            'currently_deployed' => false,
          },
          {
            'version' => '3.1-dev',
            'commit_hash' => 'unknown',
            'uncommitted_changes' => false,
            'currently_deployed' => false,
          },
          {
            'version' => '3.2-dev',
            'commit_hash' => 'unknown',
            'uncommitted_changes' => false,
            'currently_deployed' => false,
          },
          {
            'version' => '3',
            'commit_hash' => 'unknown',
            'uncommitted_changes' => false,
            'currently_deployed' => false,
          },
          {
            'version' => '4',
            'commit_hash' => 'unknown',
            'uncommitted_changes' => false,
            'currently_deployed' => false,
          },
        ],
      },
      {
        'name' => 'bosh',
        'release_versions' => [
          {
            'version' => '2',
            'commit_hash' => 'unknown',
            'uncommitted_changes' => false,
            'currently_deployed' => false,
          },
          {
            'version' => '1.2-dev',
            'commit_hash' => 'unknown',
            'uncommitted_changes' => false,
            'currently_deployed' => false,
          },
        ],
      },
    ]
  end

  describe 'resolve_stemcell_aliases' do
    let(:manifest_data) do
      {
        'resource_pools' => [
          {'stemcell' => {'name' => 'foo', 'version' => 'latest'}},
          {'stemcell' => {'name' => 'foo', 'version' => 22}},
          {'stemcell' => {'name' => 'bar', 'version' => 'latest'}},
        ]
      }
    end

    let(:stemcells) {
      [
        {'name' => 'foo', 'version' => '22.6.4'},
        {'name' => 'foo', 'version' => '22'},
        {'name' => 'bar', 'version' => '4.0.8'},
        {'name' => 'bar', 'version' => '4.1'}
      ]
    }

    context "when resolving versions with 'latest'" do
      context 'when a compatible stemcell exists' do
        it 'resolves latest alias' do
          expect(director).to receive(:list_stemcells).and_return(stemcells)
          manifest.resolve_stemcell_aliases
          expect(manifest.hash['resource_pools'][0]['stemcell']['version']).to eq('22.6.4')
          expect(manifest.hash['resource_pools'][1]['stemcell']['version']).to eq(22)
          expect(manifest.hash['resource_pools'][2]['stemcell']['version']).to eq('4.1')
        end
      end

      context 'when a compatible stemcell does not exist' do
        let(:stemcells) { [] }

        it 'raises an error' do
          expect(director).to receive(:list_stemcells).and_return(stemcells)
          expect {
            manifest.resolve_stemcell_aliases
          }.to raise_error(
            Bosh::Cli::CliError,
            "Unable to resolve stemcell 'foo' for version 'latest'."
          )
        end
      end
    end

    context "when resolving versions with '.latest' suffix" do
      context 'when a compatible stemcell version exists' do
        let(:manifest_data) do
          {
            'resource_pools' => [
              {'stemcell' => {'name' => 'foo', 'version' => '22.latest'}},
              {'stemcell' => {'name' => 'bar', 'version' => '4.0.latest'}},
            ]
          }
        end

        it 'should resolve the latest version in that series' do
          expect(director).to receive(:list_stemcells).and_return(stemcells)
          manifest.resolve_stemcell_aliases
          expect(manifest.hash['resource_pools'][0]['stemcell']['version']).to eq('22.6.4')
          expect(manifest.hash['resource_pools'][1]['stemcell']['version']).to eq('4.0.8')
        end
      end

      context 'when a compatible stemcell version does not exist' do
        let(:manifest_data) do
          {
            'resource_pools' => [
              {'stemcell' => {'name' => 'bar', 'version' => '4.2.latest'}}
            ]
          }
        end

        it 'should raise an error' do
          expect(director).to receive(:list_stemcells).and_return(stemcells)
          expect{
            manifest.resolve_stemcell_aliases
          }.to raise_error(
            Bosh::Cli::CliError,
            "Unable to resolve stemcell 'bar' for version '4.2.latest'."
          )
        end
      end

      context 'when a stemcell does not exist' do
        let(:manifest_data) do
          {
            'resource_pools' => [
              {'stemcell' => {'name' => 'baz', 'version' => '4.9.latest'}}
            ]
          }
        end

        it 'should raise an error' do
          expect(director).to receive(:list_stemcells).and_return(stemcells)
          expect{
            manifest.resolve_stemcell_aliases
          }.to raise_error(
            Bosh::Cli::CliError,
            "Unable to resolve stemcell 'baz' for version '4.9.latest'."
          )
        end
      end
    end
  end

  describe '#latest_release_versions' do
    context 'for director version < 1.5' do
      before do
        allow(director).to receive_messages(list_releases: [
              {
                'name' => 'bat',
                'versions' => ['1', '8.2-dev', '2', '8.1-dev'],
                'in_use' => ['1'],
              },
              {
                'name' => 'bosh',
                'versions' => ['2', '1.2-dev'],
                'in_use' => [],
              },
            ])
      end

      it 'should have the latest version for each release' do
        expect(manifest.latest_release_versions).to eq({
              'bat' => '8.2-dev',
              'bosh' => '2'
            })
      end
    end

    context 'for director version >= 1.5' do
      before { allow(director).to receive_messages(list_releases: [
            {
              'name' => 'bat',
              'versions' => ['1', '8.2-dev', '8+dev.3', '2', '8+dev.1'],
              'in_use' => ['1'],
            },
            {
              'name' => 'bosh',
              'versions' => ['2', '1.2-dev'],
              'in_use' => [],
            },
          ])
      }

      it 'should have the latest version for each release' do
        expect(manifest.latest_release_versions).to eq({
              'bat' => '8+dev.3',
              'bosh' => '2'
            })
      end
    end
  end

  describe '#resolve_release_aliases' do
    context 'when release versions are explicit' do
      context 'when manifest has single release' do
        let(:manifest_data) do
          {
            'release' => {
              'name' => 'bat',
              'version' => '3.1-dev'
            }
          }
        end

        it 'should leave the version as is' do
          manifest.resolve_release_aliases
          expect(manifest.hash['release']['version']).to eq('3.1-dev')
        end
      end

      context 'manifest with multiple releases' do
        let(:manifest_data) do
          {
            'releases' => [
              { 'name' => 'bat', 'version' => '3.1-dev' },
              { 'name' => 'bosh', 'version' => '1.2-dev' },
            ]
          }
        end

        it 'should leave the versions as they are' do
          manifest.resolve_release_aliases
          expect(manifest.hash['releases'].detect { |release| release['name'] == 'bat' }['version']).to eq('3.1-dev')
          expect(manifest.hash['releases'].detect { |release| release['name'] == 'bosh' }['version']).to eq('1.2-dev')
        end
      end
    end

    context "when release versions has 'latest' suffix" do
      let(:release_version) { '3.latest' }
      let(:manifest_data) do
        {
          'releases' => [
            { 'name' => 'bat', 'version' => release_version },
          ]
        }
      end

      before do
        allow(director).to receive_messages(list_releases: release_list)
      end

      context 'when the version can be resolved' do
        it 'should resolve the version to the latest for that release' do
          manifest.resolve_release_aliases
          expect(manifest.hash['releases'].detect { |release| release['name'] == 'bat' }['version']).to eq('3.2-dev')
        end

        context 'when a newer version exists' do
          let(:release_version) { '3.1.latest' }

          it 'should resolve the latest version with the same prefix' do
            manifest.resolve_release_aliases
            expect(manifest.hash['releases'].detect { |release| release['name'] == 'bat' }['version']).to eq('3.1-dev')
          end
        end
      end

      context 'when the version cannot be resolved' do
        context 'when the release does not exist' do
          let(:release_list) { [] }

          it 'raises an error' do
            expect {
              manifest.resolve_release_aliases
            }.to raise_error(
              Bosh::Cli::CliError,
              "Unable to resolve release 'bat' for version '3.latest'."
            )
          end
        end

        context 'when a compatible version does not exist' do
          let(:release_version) { '13.latest' }

          it 'raises an error' do
            expect {
              manifest.resolve_release_aliases
            }.to raise_error(
              Bosh::Cli::CliError,
              "Unable to resolve release 'bat' for version '13.latest'."
            )
          end
        end
      end
    end

    context "when some release versions are set to 'latest'" do
      let(:manifest_data) do
        {
          'releases' => [
            { 'name' => 'bat', 'version' => '3.1-dev' },
            { 'name' => 'bosh', 'version' => 'latest' },
          ]
        }
      end
      before do
        allow(director).to receive_messages(list_releases: release_list)
      end

      it 'should resolve the version to the latest for that release' do
        manifest.resolve_release_aliases
        expect(manifest.hash['releases'].detect { |release| release['name'] == 'bat' }['version']).to eq('3.1-dev')
        expect(manifest.hash['releases'].detect { |release| release['name'] == 'bosh' }['version']).to eq('2')
      end

      context 'when the release is not found on the director' do
        let(:release_list) { [] }

        it 'raises an error' do
          expect {
            manifest.resolve_release_aliases
          }.to raise_error(
              Bosh::Cli::CliError,
              "Unable to resolve release 'bosh' for version 'latest'."
            )
        end
      end
    end
  end
end
