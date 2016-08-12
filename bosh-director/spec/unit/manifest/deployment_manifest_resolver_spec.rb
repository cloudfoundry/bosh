require 'spec_helper'

module Bosh::Director
  describe DeploymentManifestResolver do
    let(:raw_manifest) do
      {
        'releases' => [
          {'name' => '((release_1_placeholder))', 'version' => 'v1'},
          {'name' => 'release_2', 'version' => '((release_2_version_placeholder))'}
        ],
        'instance_groups' => [
          {
            'name' => 'logs',
            'env' => {
              'smurf' => '((which_smurf))'
            },
            'jobs' => [
              {'name' => 'mysql', 'properties' => {'foo' => 'foo_value', 'bar' => {'smurf' => 'blue'}}},
              {'name' => '((job_name))'}
            ],
            'properties' => {'a' => ['123', 45, '((secret_key))']}
          }
        ],
        'properties' => {
          'global_property' => '((something))'
        },
        'resource_pools' => [
          {
            'name' => 'resource_pool_name',
            'env' => {
              'f' => '((f_placeholder))'
            }
          }
        ]
      }
    end

    describe '#resolve_manifest' do
      context 'when config server is disabled' do
        before do
          allow(Bosh::Director::Config).to receive(:config_server_enabled).and_return(false)
        end

        it 'injects uninterpolated env in the manifest without resolving any values' do
          actual_manifest = Bosh::Director::DeploymentManifestResolver.resolve_manifest(raw_manifest, true)
          expect(actual_manifest).to eq(
           {
             'releases' => [
               {'name' => '((release_1_placeholder))', 'version' => 'v1'},
               {'name' => 'release_2', 'version' => '((release_2_version_placeholder))'}
             ],
             'instance_groups' => [
               {
                 'name' => 'logs',
                 'env' => {
                   'smurf' => '((which_smurf))'
                 },
                 'uninterpolated_env' => {
                   'smurf' => '((which_smurf))'
                 },
                 'jobs' => [
                   {'name' => 'mysql',
                    'properties' => {'foo' => 'foo_value', 'bar' => {'smurf' => 'blue'}},
                   },
                   {'name' => '((job_name))'}
                 ],
                 'properties' => {'a' => ['123', 45, '((secret_key))']},
               }
             ],
             'properties' => {
               'global_property' => '((something))'
             },
             'resource_pools' => [
               {
                 'name' => 'resource_pool_name',
                 'env' => {
                   'f' => '((f_placeholder))'
                 },
                 'uninterpolated_env' => {
                   'f' => '((f_placeholder))'
                 }
               }
             ]
           }
         )
        end

        it 'works with legacy deployment manifests' do
          raw_manifest['jobs'] = raw_manifest['instance_groups']
          raw_manifest.delete('instance_groups')

          raw_manifest['jobs'][0]['templates'] = raw_manifest['jobs'][0]['jobs']
          raw_manifest['jobs'][0].delete('jobs')

          actual_manifest = Bosh::Director::DeploymentManifestResolver.resolve_manifest(raw_manifest, true)
          expect(actual_manifest).to eq(
             {
               'releases' => [
                   {'name' => '((release_1_placeholder))', 'version' => 'v1'},
                   {'name' => 'release_2', 'version' => '((release_2_version_placeholder))'}
               ],
               'jobs' => [
                 {
                   'name' => 'logs',
                   'env' => {
                     'smurf' => '((which_smurf))'
                   },
                   'uninterpolated_env' => {
                     'smurf' => '((which_smurf))'
                   },
                   'templates' => [
                     {'name' => 'mysql',
                      'properties' => {'foo' => 'foo_value', 'bar' => {'smurf' => 'blue'}},
                     },
                     {'name' => '((job_name))'}
                   ],
                   'properties' => {'a' => ['123', 45, '((secret_key))']},
                 }
               ],
               'properties' => {
                 'global_property' => '((something))'
               },
               'resource_pools' => [
                 {
                   'name' => 'resource_pool_name',
                   'env' => {
                     'f' => '((f_placeholder))'
                   },
                   'uninterpolated_env' => {
                     'f' => '((f_placeholder))'
                   }
                 }
               ]
             }
           )
        end
      end

      context 'when config server is enabled' do
        let(:prepared_manifest) do
          {
            'releases' => [
              {'name' => '((release_1_placeholder))', 'version' => 'v1'},
              {'name' => 'release_2', 'version' => '((release_2_version_placeholder))'}
            ],
            'instance_groups' => [
              {
                'name' => 'logs',
                'env' => {'smurf' => '((which_smurf))'},
                'uninterpolated_env' => {'smurf' => '((which_smurf))'},
                'jobs' => [
                  {
                    'name' => 'mysql',
                    'properties' => {'foo' => 'foo_value', 'bar' => {'smurf' => 'blue'}},
                  },
                  {
                    'name' => '((job_name))'
                  }
                ],
                'properties' =>  {'a' => ['123', 45, '((secret_key))']},
              }
            ],
            'properties' => {
              'global_property' => '((something))'
            },
            'resource_pools' => [
              {
                'name' => 'resource_pool_name',
                'env' => {
                  'f' => '((f_placeholder))'
                },
                'uninterpolated_env' => {
                  'f' => '((f_placeholder))'
                }
              }
            ]
          }
        end

        let(:resolved_manifest) do
          {
            'releases' => [
              {'name' => 'release_1', 'version' => 'v1'},
              {'name' => 'release_2', 'version' => 'v2'}
            ],
            'instance_groups' => [
              {
                'name' => 'logs',
                'env' => {'smurf' => 'lazy'},
                'uninterpolated_env' => {'smurf' => '((which_smurf))'},
                'jobs' => [
                  {
                    'name' => 'mysql',
                    'properties' => {'foo' => '((foo_place_holder))', 'bar' => {'smurf' => '((smurf_placeholder))'}}
                  },
                  {
                    'name' => '((job_name))'
                  }
                ],
                'properties' => {'a' => ['123', 45, '((secret_key))']}
              }
            ],
            'properties' => {
              'global_property' => '((something))'
            },
            'resource_pools' => [
              {
                'name' => 'resource_pool_name',
                'env' => {
                  'f' => 'f_value'
                },
                'uninterpolated_env' => {
                  'f' => '((f_placeholder))'
                }
              }
            ]
          }
        end

        let(:my_numeric) {Numeric.new}
        let(:ignored_subtrees) do
          index_type = Integer
          any_string = String

          ignored_subtrees = []
          ignored_subtrees << ['properties']
          ignored_subtrees << ['instance_groups', index_type, 'properties']
          ignored_subtrees << ['instance_groups', index_type, 'jobs', index_type, 'properties']
          ignored_subtrees << ['instance_groups', index_type, 'jobs', index_type, 'consumes', any_string, 'properties']
          ignored_subtrees << ['jobs', index_type, 'properties']
          ignored_subtrees << ['jobs', index_type, 'templates', index_type, 'properties']
          ignored_subtrees << ['jobs', index_type, 'templates', index_type, 'consumes', any_string, 'properties']
          ignored_subtrees << ['instance_groups', index_type, 'uninterpolated_env']
          ignored_subtrees << ['jobs', index_type, 'uninterpolated_env']
          ignored_subtrees << ['resource_pools', index_type, 'uninterpolated_env']
          ignored_subtrees
        end

        before do
          allow(Bosh::Director::Config).to receive(:config_server_enabled).and_return(true)
        end

        it 'injects uninterpolated properties in the the manifest and resolve the values' do
          # TODO: Need to change this test when using the dependency injection path
          expect(Bosh::Director::ConfigServer::ConfigParser).to receive(:parse).with(prepared_manifest, ignored_subtrees).and_return(resolved_manifest)
          actual_manifest = Bosh::Director::DeploymentManifestResolver.resolve_manifest(raw_manifest, true)

          expect(actual_manifest).to eq(resolved_manifest)
        end

        context 'when resolve_interpolation flag is false' do
          it 'injects uninterpolated properties in the the manifest but does not resolve the values' do
            expect(Bosh::Director::ConfigServer::ConfigParser).to_not receive(:parse)
            actual_manifest = Bosh::Director::DeploymentManifestResolver.resolve_manifest(raw_manifest, false)
            expect(actual_manifest).to eq(
              {
               'releases' => [
                 {'name' => '((release_1_placeholder))', 'version' => 'v1'},
                 {'name' => 'release_2', 'version' => '((release_2_version_placeholder))'}
               ],
               'instance_groups' => [
                 {
                   'name' => 'logs',
                   'env' => {'smurf' => '((which_smurf))'},
                   'uninterpolated_env' => {'smurf' => '((which_smurf))'},
                   'jobs' => [
                     {'name' => 'mysql',
                      'properties' => {'foo' => 'foo_value', 'bar' => {'smurf' => 'blue'}},
                     },
                     {'name' => '((job_name))'}
                   ],
                   'properties' => {'a' => ['123', 45, '((secret_key))']},
                 }
               ],
               'properties' => {
                 'global_property' => '((something))'
               },
               'resource_pools' => [
                 {
                   'name' => 'resource_pool_name',
                   'env' => {
                     'f' => '((f_placeholder))'
                   },
                   'uninterpolated_env' => {
                     'f' => '((f_placeholder))'
                   }
                 }
               ]
              }
            )
          end
        end
      end
    end
  end
end
