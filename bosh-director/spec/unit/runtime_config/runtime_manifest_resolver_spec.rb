require 'spec_helper'

module Bosh::Director
  describe RuntimeConfig::RuntimeManifestResolver do
    let(:raw_runtime_config_manifest) do
      {
        'releases' => [
          {'name' => 'release_1', 'version' => 'v1'},
          {'name' => 'release_2', 'version' => 'v2'}
        ],
        'addons' => [
          {
            'name' => 'logs',
            'jobs' => [
              {
                  'name' => 'mysql',
                  'template' => 'template1',
                  'properties' => {
                      'foo' => 'foo_value',
                      'bar' => {
                          'smurf' => 'blue',
                      },
                  },
                  'consumes' => {
                      'db' => {
                          'type' => '((interpolated_type))',
                          'properties' => {
                              'bar' => {
                                  'smurf' => 'blue',
                              },
                              'interpolate' => '((valuable))',
                          },
                      },
                  },
              },
              {
                  'name' => '((job_name))',
                  'template' => 'template1',
              },
            ],
            'properties' => {'a' => ['123', 45, '((secret_key))']}
          }
        ],
      }
    end

    describe '#resolve_manifest' do
      context 'when config server is disabled' do
        before do
          allow(Bosh::Director::Config).to receive(:config_server_enabled).and_return(false)
        end

        it 'return manifest as is' do
          raw_runtime_config_manifest = Bosh::Director::RuntimeConfig::RuntimeManifestResolver.resolve_manifest(raw_runtime_config_manifest)
        end
      end

      context 'when config server is enabled' do
        before do
          allow(Bosh::Director::Config).to receive(:config_server_enabled).and_return(true)
        end

        let(:ignored_subtrees) do
          index_type = Integer

          ignored_subtrees = []
          ignored_subtrees << ['addons', index_type, 'properties']
          ignored_subtrees << ['addons', index_type, 'jobs', index_type, 'properties']
          ignored_subtrees << ['addons', index_type, 'jobs', index_type, 'consumes', String, 'properties']
          ignored_subtrees
        end

        it 'calls the ConfigParser with correct parameters' do
          expect(Bosh::Director::ConfigServer::ConfigParser).to receive(:parse).with(raw_runtime_config_manifest, ignored_subtrees)

          Bosh::Director::RuntimeConfig::RuntimeManifestResolver.resolve_manifest(raw_runtime_config_manifest)
        end
      end
    end
  end
end
