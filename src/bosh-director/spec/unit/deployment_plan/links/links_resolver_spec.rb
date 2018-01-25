require 'spec_helper'

describe Bosh::Director::DeploymentPlan::LinksResolver do
  subject(:links_resolver) {described_class.new(deployment_plan, logger)}

  let(:deployment_plan) do
    planner_factory = Bosh::Director::DeploymentPlan::PlannerFactory.create(logger)
    manifest = Bosh::Director::Manifest.load_from_hash(deployment_manifest, YAML.dump(deployment_manifest), [], [], {:resolve_interpolation => false})
    planner = planner_factory.create_from_manifest(manifest, [], [], {})
    Bosh::Director::DeploymentPlan::Assembler.create(planner).bind_models
    planner
  end

  let(:deployment_manifest) do
    generate_deployment_manifest('fake-deployment', links, ['127.0.0.3', '127.0.0.4'])
  end

  let(:manifest_job_provides) do
    {'db' => {'as' => 'db'}}
  end

  def generate_deployment_manifest(name, links, mysql_static_ips)
    {
      'name' => name,
      'instance_groups' => [
        {
          'name' => 'api-server',
          'jobs' => [
            {'name' => 'api-server-template', 'release' => 'fake-release', 'consumes' => links},
            {'name' => 'template-without-links', 'release' => 'fake-release'}
          ],
          'resource_pool' => 'fake-resource-pool',
          'instances' => 1,
          'networks' => [
            {
              'name' => 'fake-manual-network',
              'static_ips' => ['127.0.0.2']
            }
          ],
        },
        {
          'name' => 'mysql',
          'jobs' => [
            {
              'name' => 'mysql-template',
              'release' => 'fake-release',
              'provides' => manifest_job_provides,
              'properties' => {'mysql' => nil}
            }
          ],
          'resource_pool' => 'fake-resource-pool',
          'instances' => 2,
          'networks' => [
            {
              'name' => 'fake-manual-network',
              'static_ips' => mysql_static_ips,
              'default' => ['dns', 'gateway']
            },
            {
              'name' => 'fake-dynamic-network',
            }
          ],
        }
      ],
      'resource_pools' => [
        {
          'name' => 'fake-resource-pool',
          'stemcell' => {
            'name' => 'fake-stemcell',
            'version' => 'fake-stemcell-version',
          },
          'network' => 'fake-manual-network',
        }
      ],
      'networks' => [
        {
          'name' => 'fake-manual-network',
          'type' => 'manual',
          'subnets' => [
            {
              'name' => 'fake-subnet',
              'range' => '127.0.0.0/20',
              'gateway' => '127.0.0.1',
              'static' => ['127.0.0.2'].concat(mysql_static_ips),
            }
          ]
        },
        {
          'name' => 'fake-dynamic-network',
          'type' => 'dynamic',
        }
      ],
      'releases' => [
        {
          'name' => 'fake-release',
          'version' => 'latest',
        }
      ],
      'compilation' => {
        'workers' => 1,
        'network' => 'fake-manual-network',
      },
      'update' => {
        'canaries' => 1,
        'max_in_flight' => 1,
        'canary_watch_time' => 1,
        'update_watch_time' => 1,
      },
    }
  end

  let(:logger) {Logging::Logger.new('TestLogger')}

  let(:api_server_instance_group) do
    deployment_plan.instance_group('api-server')
  end

  def create_new_release(version, api_server_template_consumes_links, mysql_template_provides_links)
    release_model = Bosh::Director::Models::Release.find_or_create(name: 'fake-release')
    version = Bosh::Director::Models::ReleaseVersion.make(version: version)
    release_id = version.release_id
    release_model.add_version(version)

    template_model = Bosh::Director::Models::Template.make(
      name: 'api-server-template',
      spec: {consumes: api_server_template_consumes_links},
      release_id: release_model.id)
    version.add_template(template_model)

    template_model = Bosh::Director::Models::Template.make(name: 'template-without-links')
    version.add_template(template_model)

    template_model = Bosh::Director::Models::Template.make(
      name: 'mysql-template',
      spec: {
        provides: mysql_template_provides_links,
        properties: {mysql: {description: 'some description'}, oranges: {description: 'shades of orange'}, pineapples: {description: 'types of the tasty fruit'}},
      },
      release_id: release_model.id)
    version.add_template(template_model)

    version
  end

  before do
    Bosh::Director::App.new(Bosh::Director::Config.load_hash(SpecHelper.spec_get_director_config))
    fake_locks

    Bosh::Director::Models::Stemcell.make(name: 'fake-stemcell', version: 'fake-stemcell-version')

    Bosh::Director::Config.dns = {'address' => 'fake-dns-address'}

    version = create_new_release('1.0.0', template_consumes_links, template_provides_links)

    deployment_model = Bosh::Director::Models::Deployment.make(name: 'fake-deployment')
    Bosh::Director::Models::VariableSet.make(deployment: deployment_model)
    version.add_deployment(deployment_model)

    deployment_model = Bosh::Director::Models::Deployment.make(
      name: 'other-deployment',
      manifest: deployment_manifest.to_json,
      # link_spec_json: '{"mysql":{"mysql-template":{"db":{"db":{}}}}}'
    )
    Bosh::Director::Models::VariableSet.make(deployment: deployment_model)
    version.add_deployment(deployment_model)
  end

  let(:template_consumes_links) {[{name: "db", type: "db"}]}
  let(:template_provides_links) {[{name: "db", type: "db", shared: true, properties: ['mysql']}]}

  describe '#resolve' do
    context 'when job consumes link from another deployment' do
      let(:link_spec) {
        {
          'mysql' => {
            'mysql-template' => {
              'db' => {
                'db' => {
                  'deployment_name' => 'other-deployment', 'networks' => ['fake-manual-network', 'fake-dynamic-network'], 'properties' => {
                    'mysql' => nil
                  },
                  'default_network' => 'fake-manual-network',
                  'instances' => [
                    {
                      'name' => 'mysql',
                      'index' => 0,
                      'bootstrap' => true,
                      'id' => '7aed7038-0b3f-4dba-ac6a-da8932502c00',
                      'az' => nil,
                      'dns_addresses' => {'fake-manual-network' => '7aed7038-0b3f-4dba-ac6a-da8932502c00.mysql.fake-manual-network.other-deployment.bosh', 'fake-dynamic-network' => '7aed7038-0b3f-4dba-ac6a-da8932502c00.mysql.fake-dynamic-network.other-deployment.bosh'},
                      'addresses' => {'fake-manual-network' => '127.0.0.4', 'fake-dynamic-network' => '7aed7038-0b3f-4dba-ac6a-da8932502c00.mysql.fake-dynamic-network.other-deployment.bosh'}
                    },
                    {
                      'name' => 'mysql',
                      'index' => 1,
                      'bootstrap' => false,
                      'id' => 'adecbe93-e242-4585-acde-ffbc1dad4b41',
                      'az' => nil,
                      'dns_addresses' => {'fake-manual-network' => 'adecbe93-e242-4585-acde-ffbc1dad4b41.mysql.fake-manual-network.other-deployment.bosh', 'fake-dynamic-network' => 'adecbe93-e242-4585-acde-ffbc1dad4b41.mysql.fake-dynamic-network.other-deployment.bosh'},
                      'addresses' => {'fake-manual-network' => '127.0.0.5', 'fake-dynamic-network' => 'adecbe93-e242-4585-acde-ffbc1dad4b41.mysql.fake-dynamic-network.other-deployment.bosh'}
                    }
                  ]
                }
              }
            }
          }
        }
      }

      context 'when another deployment has link source' do
        before do
          # Bosh::Director::Models::Deployment.where(name: 'other-deployment').first.update(link_spec: link_spec)

          provider = Bosh::Director::Models::Links::LinkProvider.create(
            deployment: Bosh::Director::Models::Deployment.find(name: 'other-deployment'),
            instance_group: 'mysql',
            name: 'mysql-template',
            type: 'job'
          )

          Bosh::Director::Models::Links::LinkProviderIntent.create(
            link_provider: provider,
            shared: true,
            consumable: true,
            original_name: 'db',
            type: 'db',
            name: 'db',
            content: {
              "deployment_name" => "other-deployment",
              "default_network" => "fake-manual-network",
              "networks" => [
                "fake-manual-network",
                "fake-dynamic-network"
              ],
              "properties" => {
                "mysql" => "nil"
              },
              'instance_group' => 'mysql',
              'instances' => [
                {
                  'name' => 'mysql',
                  'index' => 0,
                  'bootstrap' => true,
                  'id' => '7aed7038-0b3f-4dba-ac6a-da8932502c00',
                  'az' => nil,
                  'dns_addresses' => {'fake-manual-network' => '7aed7038-0b3f-4dba-ac6a-da8932502c00.mysql.fake-manual-network.other-deployment.bosh', 'fake-dynamic-network' => '7aed7038-0b3f-4dba-ac6a-da8932502c00.mysql.fake-dynamic-network.other-deployment.bosh'},
                  'addresses' => {'fake-manual-network' => '127.0.0.4', 'fake-dynamic-network' => '7aed7038-0b3f-4dba-ac6a-da8932502c00.mysql.fake-dynamic-network.other-deployment.bosh'}
                },
                {
                  'name' => 'mysql',
                  'index' => 1,
                  'bootstrap' => false,
                  'id' => 'adecbe93-e242-4585-acde-ffbc1dad4b41',
                  'az' => nil,
                  'dns_addresses' => {'fake-manual-network' => 'adecbe93-e242-4585-acde-ffbc1dad4b41.mysql.fake-manual-network.other-deployment.bosh', 'fake-dynamic-network' => 'adecbe93-e242-4585-acde-ffbc1dad4b41.mysql.fake-dynamic-network.other-deployment.bosh'},
                  'addresses' => {'fake-manual-network' => '127.0.0.5', 'fake-dynamic-network' => 'adecbe93-e242-4585-acde-ffbc1dad4b41.mysql.fake-dynamic-network.other-deployment.bosh'}
                }
              ]
            }.to_json
          )
        end

        context 'when requesting for ip addresses only' do
          let(:links) {{'db' => {"from" => 'db', 'deployment' => 'other-deployment', 'ip_addresses' => true}}}

          it 'returns link from another deployment' do
            links_resolver.resolve(api_server_instance_group)

            provider_dep = Bosh::Director::Models::Deployment.where(name: 'other-deployment').first

            spec = {
              'default_network' => 'fake-manual-network',
              'deployment_name' => provider_dep.name,
              'instance_group' => 'mysql',
              'instances' => [
                {
                  'name' => 'mysql',
                  'index' => 0,
                  "bootstrap" => true,
                  'id' => '7aed7038-0b3f-4dba-ac6a-da8932502c00',
                  'az' => nil,
                  'address' => '127.0.0.4'
                },
                {
                  'name' => 'mysql',
                  'index' => 1,
                  "bootstrap" => false,
                  'id' => 'adecbe93-e242-4585-acde-ffbc1dad4b41',
                  'az' => nil,
                  'address' => '127.0.0.5'
                }
              ],
              'networks' => ['fake-manual-network', 'fake-dynamic-network'],
              "properties" => {"mysql" => "nil"}
            }
            links_hash = {"api-server-template" => {"db" => spec}}
            expect(api_server_instance_group.resolved_links).to include(links_hash)

          end
        end

        context 'when requesting for DNS entries' do
          let(:links) {{'db' => {"from" => 'db', 'deployment' => 'other-deployment', 'ip_addresses' => false}}}

          it 'returns link from another deployment' do
            links_resolver.resolve(api_server_instance_group)

            provider_dep = Bosh::Director::Models::Deployment.where(name: 'other-deployment').first

            spec = {
              'deployment_name' => provider_dep.name,
              'networks' => ['fake-manual-network', 'fake-dynamic-network'],
              'default_network' => 'fake-manual-network',
              "properties" => {"mysql" => "nil"},
              'instance_group' => 'mysql',
              'instances' => [
                {
                  'name' => 'mysql',
                  'index' => 0,
                  "bootstrap" => true,
                  'id' => '7aed7038-0b3f-4dba-ac6a-da8932502c00',
                  'az' => nil,
                  'address' => '7aed7038-0b3f-4dba-ac6a-da8932502c00.mysql.fake-manual-network.other-deployment.bosh'
                },
                {
                  'name' => 'mysql',
                  'index' => 1,
                  "bootstrap" => false,
                  'id' => 'adecbe93-e242-4585-acde-ffbc1dad4b41',
                  'az' => nil,
                  'address' => 'adecbe93-e242-4585-acde-ffbc1dad4b41.mysql.fake-manual-network.other-deployment.bosh'
                }
              ]
            }

            links_hash = {"api-server-template" => {"db" => spec}}

            expect(api_server_instance_group.resolved_links).to eq(links_hash)
          end
        end

        context 'when other deployment link type does not match' do
          let(:links) {{'db' => {"from" => 'db', 'deployment' => 'other-deployment'}}}

          let(:template_consumes_links) {[{'name' => 'db', 'type' => 'other'}]}
          let(:template_provides_links) {[{name: "db", type: "db"}]} # name and type is implicitly db

          it 'fails' do
            expect {
              links_resolver.resolve(api_server_instance_group)
            }.to raise_error Bosh::Director::DeploymentInvalidLink, "Can't resolve link 'db' in instance group 'api-server' on job 'api-server-template' in deployment 'fake-deployment'. Please make sure the link was provided and shared."
          end
        end
      end

      context 'when another deployment does not have link source' do
        let(:links) {{'db' => {"from" => 'bad_alias', 'deployment' => 'other-deployment'}}}

        it 'fails' do
          expected_error_msg = "Can't resolve link 'bad_alias' in instance group 'api-server' on job 'api-server-template' in deployment 'fake-deployment'. Please make sure the link was provided and shared."

          expect {
            links_resolver.resolve(api_server_instance_group)
          }.to raise_error(Bosh::Director::DeploymentInvalidLink, expected_error_msg)
        end
      end

      context 'when requested deployment does not exist' do
        let(:links) {{'db' => {"from" => 'db', 'deployment' => 'non-existent'}}}

        it 'fails' do
          expected_error_msg = <<-EXPECTED.strip
Deployment non-existent not found for consumed link db
          EXPECTED

          expect {
            links_resolver.resolve(api_server_instance_group)
          }.to raise_error(expected_error_msg)
        end
      end
    end

    context 'when provided link type does not match required link type' do
      let(:links) {{'db' => {"from" => 'db'}}}

      let(:template_consumes_links) {[{'name' => 'db', 'type' => 'other'}]}
      let(:template_provides_links) {[{name: "db", type: "db"}]} # name and type is implicitly db

      it 'fails to find link' do
        expect {
          links_resolver.resolve(api_server_instance_group)
        }.to raise_error Bosh::Director::DeploymentInvalidLink, "Can't resolve link 'db' in instance group 'api-server' on job 'api-server-template' in deployment 'fake-deployment'."
      end
    end

    context 'when link source is does not specify deployment name' do
      let(:links) {{'db' => {"from" => 'db'}}}

      it 'defaults to current deployment' do
        links_resolver.resolve(api_server_instance_group)
        link_spec = api_server_instance_group.resolved_links['api-server-template']['db']
        expect(link_spec['instances'].first['name']).to eq('mysql')
        expect(link_spec['deployment_name']).to eq(api_server_instance_group.deployment_name)
        expect(link_spec['instance_group']).to eq('mysql')
      end
    end

    context 'when required link is not specified in manifest' do
      let(:links) {{'other' => {"from" => 'c'}}}
      let(:template_consumes_links) {[{'name' => 'other', 'type' => 'db'}]}

      it 'fails' do
        expected_error_msg = "Can't resolve link 'c' in instance group 'api-server' on job 'api-server-template' in deployment 'fake-deployment'."

        expect {
          links_resolver.resolve(api_server_instance_group)
        }.to raise_error(Bosh::Director::DeploymentInvalidLink, expected_error_msg)
      end
    end

    context 'when link specified in manifest is not required' do
      # TODO LINKS: Move to instance_group_spec_parser_spec.
      let(:links) {{'db' => {"from" => 'db'}}}

      let(:template_consumes_links) {[]}
      let(:template_provides_links) {[{'name' => 'db', 'type' => 'db'}]}

      it 'raises unused link error' do
        expect {
          links_resolver.resolve(api_server_instance_group)
        }.to raise_error "Job 'api-server-template' does not define link 'db' in the release spec"
      end
    end

    context 'when there is a cloud config' do
      let(:deployment_plan) do
        planner_factory = Bosh::Director::DeploymentPlan::PlannerFactory.create(logger)
        manifest = Bosh::Director::Manifest.load_from_hash(deployment_manifest, YAML.dump(deployment_manifest), cloud_configs, [], {:resolve_interpolation => false})

        planner = planner_factory.create_from_manifest(manifest, cloud_configs, [], {})
        Bosh::Director::DeploymentPlan::Assembler.create(planner).bind_models
        planner
      end

      let(:links) {{'db' => {'from' => 'db'}}}

      let(:deployment_manifest) {generate_manifest_without_cloud_config('fake-deployment', links, ['127.0.0.3', '127.0.0.4'])}

      let(:cloud_configs) do
        [
          Bosh::Director::Models::Config.make(:cloud, content: YAML.dump(
            {
              'azs' => [
                {
                  'name' => 'az1',
                  'cloud_properties' => {}
                },
                {
                  'name' => 'az2',
                  'cloud_properties' => {}
                }
              ],
              'networks' => [
                {
                  'name' => 'fake-manual-network',
                  'type' => 'manual',
                  'subnets' => [
                    {
                      'name' => 'fake-subnet',
                      'range' => '127.0.0.0/20',
                      'gateway' => '127.0.0.1',
                      'az' => 'az1',
                      'static' => ['127.0.0.2', '127.0.0.3', '127.0.0.4'],
                    }
                  ]
                },
                {
                  'name' => 'fake-dynamic-network',
                  'type' => 'dynamic',
                  'subnets' => [
                    {'az' => 'az1'}
                  ]
                }
              ],
              'compilation' => {
                'workers' => 1,
                'network' => 'fake-manual-network',
                'az' => 'az1',
              },
              'vm_types' => [
                {
                  'name' => 'fake-vm-type',
                }
              ]
            }))
        ]
      end

      def generate_manifest_without_cloud_config(name, links, mysql_static_ips)
        {
          'name' => name,
          'releases' => [
            {
              'name' => 'fake-release',
              'version' => '1.0.0',
            }
          ],
          'update' => {
            'canaries' => 1,
            'max_in_flight' => 1,
            'canary_watch_time' => 1,
            'update_watch_time' => 1,
          },
          'jobs' => [
            {
              'name' => 'api-server',
              'stemcell' => 'fake-stemcell',
              'templates' => [
                {'name' => 'api-server-template', 'release' => 'fake-release', 'consumes' => links}
              ],
              'vm_type' => 'fake-vm-type',
              'azs' => ['az1'],
              'instances' => 1,
              'networks' => [
                {
                  'name' => 'fake-manual-network',
                  'static_ips' => ['127.0.0.2']
                }
              ],
            },
            {
              'name' => 'mysql',
              'stemcell' => 'fake-stemcell',
              'templates' => [
                {
                  'name' => 'mysql-template',
                  'release' => 'fake-release',
                  'provides' => {'db' => {'as' => 'db'}},
                  'properties' => {'mysql' => nil}
                }
              ],
              'vm_type' => 'fake-vm-type',
              'instances' => 2,
              'azs' => ['az1'],
              'networks' => [
                {
                  'name' => 'fake-manual-network',
                  'static_ips' => mysql_static_ips,
                  'default' => ['dns', 'gateway'],

                },
                {
                  'name' => 'fake-dynamic-network',
                }
              ],
            },
          ],
          'stemcells' => [
            {
              'alias' => 'fake-stemcell',
              'version' => 'fake-stemcell-version',
              'name' => 'fake-stemcell'
            }
          ]
        }
      end

      it 'adds link to job' do
        Bosh::Director::Config.current_job = Bosh::Director::Jobs::BaseJob.new
        Bosh::Director::Config.current_job.task_id = 'fake-task-id'

        links_resolver.resolve(api_server_instance_group)
        instance1 = Bosh::Director::Models::Instance.where(job: 'mysql', index: 0).first
        instance2 = Bosh::Director::Models::Instance.where(job: 'mysql', index: 1).first

        link_spec = {
          'deployment_name' => api_server_instance_group.deployment_name,
          'domain' => 'bosh',
          'default_network' => 'fake-manual-network',
          'instance_group' => 'mysql',
          'networks' => ['fake-manual-network', 'fake-dynamic-network'],
          "properties" => {"mysql" => nil},
          'instances' => [
            {
              'name' => 'mysql',
              'index' => 0,
              "bootstrap" => true,
              'id' => instance1.uuid,
              'az' => 'az1',
              'address' => '127.0.0.3',
            },
            {
              'name' => 'mysql',
              'index' => 1,
              "bootstrap" => false,
              'id' => instance2.uuid,
              'az' => 'az1',
              'address' => '127.0.0.4',
            }
          ]
        }

        links_hash = {"api-server-template" => {"db" => link_spec}}

        expect(api_server_instance_group.resolved_links).to eq(links_hash)
      end
    end
  end
end
