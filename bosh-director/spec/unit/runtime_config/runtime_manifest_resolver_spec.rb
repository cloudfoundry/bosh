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
              {'name' => 'mysql', 'template' => 'template1', 'properties' => {'foo' => 'foo_value', 'bar' => {'smurf' => 'blue'}}},
              {'name' => '((job_name))', 'template' => 'template1'}
            ],
            'properties' => {'a' => ['123', 45, '((secret_key))']}
          }
        ],
      }
    end

    describe '#resolve_manifest' do
      context 'when config server is enabled' do
        before do
          allow(Bosh::Director::Config).to receive(:config_server_enabled).and_return(false)
        end

        it 'injects uninterpolated properties in the the manifest' do
          actual_manifest = Bosh::Director::RuntimeConfig::RuntimeManifestResolver.resolve_manifest(raw_runtime_config_manifest)
          expect(actual_manifest).to eq(
             {
               'releases' => [
                 {'name' => 'release_1', 'version' => 'v1'},
                 {'name' => 'release_2', 'version' => 'v2'}
               ],
               'addons' => [
                 {
                   'name' => 'logs',
                   'jobs' => [
                     {'name' => 'mysql',
                      'template' => 'template1',
                      'properties' => {'foo' => 'foo_value', 'bar' => {'smurf' => 'blue'}},
                      'uninterpolated_properties' => {'foo' => 'foo_value', 'bar' => {'smurf' => 'blue'}}
                     },
                     {'name' => '((job_name))', 'template' => 'template1'}
                   ],
                   'properties' => {'a' => ['123', 45, '((secret_key))']},
                   'uninterpolated_properties' => {'a' => ['123', 45, '((secret_key))']}
                 }
               ],
             }
          )
        end
      end

      context 'when config server is enabled' do
        let(:injected_manifest) {
          {
            'releases' => [
              {'name' => 'release_1', 'version' => 'v1'},
              {'name' => 'release_2', 'version' => 'v2'}
            ],
            'addons' => [
              {
                'name' => 'logs',
                'jobs' => [
                  {'name' => 'mysql',
                   'template' => 'template1',
                   'properties' => {'foo' => 'foo_value', 'bar' => {'smurf' => 'blue'}},
                   'uninterpolated_properties' => {'foo' => 'foo_value', 'bar' => {'smurf' => 'blue'}}
                  },
                  {'name' => '((job_name))', 'template' => 'template1'}
                ],
                'properties' => {'a' => ['123', 45, '((secret_key))']},
                'uninterpolated_properties' => {'a' => ['123', 45, '((secret_key))']}
              }
            ],
          }
        }

        let(:resolved_manifest) {
          {
            'releases' => [
              {'name' => 'release_1', 'version' => 'v1'},
              {'name' => 'release_2', 'version' => 'v2'}
            ],
            'addons' => [
              {
                'name' => 'logs',
                'jobs' => [
                  {'name' => 'mysql',
                   'template' => 'template1',
                   'properties' => {'foo' => 'foo_value', 'bar' => {'smurf' => 'blue'}},
                   'uninterpolated_properties' => {'foo' => 'foo_value', 'bar' => {'smurf' => 'blue'}}
                  },
                  {'name' => 'hello', 'template' => 'template1'}
                ],
                'properties' => {'a' => ['123', 45, 'test']},
                'uninterpolated_properties' => {'a' => ['123', 45, '((secret_key))']}
              }
            ],
          }
        }

        let(:ignored_subtrees) do
          index_type = Integer

          ignored_subtrees = []
          ignored_subtrees << ['addons', index_type, 'uninterpolated_properties']
          ignored_subtrees << ['addons', index_type, 'jobs', index_type, 'uninterpolated_properties']
          ignored_subtrees
        end

        before do
          allow(Bosh::Director::Config).to receive(:config_server_enabled).and_return(true)
        end

        it 'injects uninterpolated properties in the the manifest' do
          expect(Bosh::Director::ConfigServer::ConfigParser).to receive(:parse).with(injected_manifest, ignored_subtrees).and_return(resolved_manifest)
          actual_manifest = Bosh::Director::RuntimeConfig::RuntimeManifestResolver.resolve_manifest(raw_runtime_config_manifest)

          expect(actual_manifest).to eq(resolved_manifest)
        end
      end
    end
  end
end
