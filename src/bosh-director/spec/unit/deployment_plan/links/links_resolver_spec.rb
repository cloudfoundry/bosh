require 'spec_helper'

describe Bosh::Director::DeploymentPlan::LinksResolver do
  subject(:links_resolver) { described_class.new(deployment_plan, logger) }

  let(:deployment_plan) do
    planner_factory = Bosh::Director::DeploymentPlan::PlannerFactory.create(logger)
    manifest = Bosh::Director::Manifest.load_from_hash(deployment_manifest, nil, [], {:resolve_interpolation => false})
    planner = planner_factory.create_from_manifest(manifest, nil, [], {})
    Bosh::Director::DeploymentPlan::Assembler.create(planner).bind_models
    planner
  end

  let(:deployment_manifest) do
    generate_deployment_manifest('fake-deployment', links, ['127.0.0.3', '127.0.0.4'])
  end

  def generate_deployment_manifest(name, links, mysql_static_ips)
    {
      'name' => name,
      'jobs' => [
        {
          'name' => 'api-server',
          'templates' => [
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
          'templates' => [
            {'name' => 'mysql-template',
              'release' => 'fake-release',
              'provides' => {'db' => {'as' => 'db'}},
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
          'version' => '1.0.0',
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

  let(:logger) { Logging::Logger.new('TestLogger') }

  let(:api_server_instance_group) do
    deployment_plan.instance_group('api-server')
  end

  before do
    Bosh::Director::App.new(Bosh::Director::Config.load_hash(SpecHelper.spec_get_director_config))
    fake_locks

    Bosh::Director::Models::Stemcell.make(name: 'fake-stemcell', version: 'fake-stemcell-version')

    Bosh::Director::Config.dns = {'address' => 'fake-dns-address'}

    release_model = Bosh::Director::Models::Release.make(name: 'fake-release')
    version = Bosh::Director::Models::ReleaseVersion.make(version: '1.0.0')
    release_id = version.release_id
    release_model.add_version(version)

    template_model = Bosh::Director::Models::Template.make(name: 'api-server-template',
      consumes: consumes_links,
      release_id: 1)
    version.add_template(template_model)

    template_model = Bosh::Director::Models::Template.make(name: 'template-without-links')
    version.add_template(template_model)

    template_model = Bosh::Director::Models::Template.make(name: 'mysql-template',
      provides: provided_links,
      properties: {mysql: {description: 'some description'}},
      release_id: 1)
    version.add_template(template_model)

    deployment_model = Bosh::Director::Models::Deployment.make(name: 'fake-deployment',
      link_spec_json: '{"mysql":{"mysql-template":{"db":{"name":"db","type":"db"}}}}')
    Bosh::Director::Models::VariableSet.make(deployment: deployment_model)
    version.add_deployment(deployment_model)

    deployment_model = Bosh::Director::Models::Deployment.make(name: 'other-deployment',
      manifest: deployment_manifest.to_json,
      link_spec_json: '{"mysql":{"mysql-template":{"db":{"name":"db","type":"db"}}}}')
    Bosh::Director::Models::VariableSet.make(deployment: deployment_model)
    version.add_deployment(deployment_model)
  end

  let(:consumes_links) { [{name: "db", type: "db"}] }
  let(:provided_links) { [{name: "db", type: "db", shared: true, properties: ['mysql']}] }

  describe '#resolve' do
    context 'when job consumes link from the same deployment' do
      context 'when link source is provided by some job' do
        let(:links) { {'db' => {"from" => 'db'}} }

        it 'adds link to job' do
          links_resolver.resolve(api_server_instance_group)
          instance1 = Bosh::Director::Models::Instance.where(job: 'mysql', index: 0).first
          instance2 = Bosh::Director::Models::Instance.where(job: 'mysql', index: 1).first

          spec = {
            'deployment_name' => api_server_instance_group.deployment_name,
            'domain' => 'bosh',
            'default_network' => 'fake-manual-network',
            'source_instance_group' => 'mysql',
            "networks" => ["fake-manual-network", "fake-dynamic-network"],
            "properties" => {"mysql" => nil},
            "instances" => [
              {
                "index" => 0,
                "bootstrap" => true,
                "id" => instance1.uuid,
                "az" => nil,
                "address" => "127.0.0.3",
              },
              {
                "index" => 1,
                "bootstrap" => false,
                "id" => instance2.uuid,
                "az" => nil,
                "address" => "127.0.0.4",
              }
            ]
          }

          links_hash = {"api-server-template" => {"db" => spec}}

          expect(api_server_instance_group.resolved_links).to eq(links_hash)
        end
      end
    end

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
          Bosh::Director::Models::Deployment.where(name: 'other-deployment').first.update(link_spec: link_spec)
        end

        context 'when requesting for ip addresses only' do
          let(:links) { {'db' => {"from" => 'db', 'deployment' => 'other-deployment', 'ip_addresses' => true}} }

          it 'returns link from another deployment' do
            links_resolver.resolve(api_server_instance_group)

            provider_dep = Bosh::Director::Models::Deployment.where(name: 'other-deployment').first

            spec = {
              'deployment_name' => provider_dep.name,
              'networks' => ['fake-manual-network', 'fake-dynamic-network'],
              "properties" => {"mysql" => nil},
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
              ]
            }

            links_hash = {"api-server-template" => {"db" => spec}}

            expect(api_server_instance_group.resolved_links).to eq(links_hash)
          end
        end

        context 'when requesting for DNS entries' do
          let(:links) { {'db' => {"from" => 'db', 'deployment' => 'other-deployment', 'ip_addresses' => false}} }

          it 'returns link from another deployment' do
            links_resolver.resolve(api_server_instance_group)

            provider_dep = Bosh::Director::Models::Deployment.where(name: 'other-deployment').first

            spec = {
              'deployment_name' => provider_dep.name,
              'networks' => ['fake-manual-network', 'fake-dynamic-network'],
              "properties" => {"mysql" => nil},
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
      end

      context 'when another deployment does not have link source' do
        let(:links) { {'db' => {"from" => 'db', 'deployment' => 'non-existent'}} }

        it 'fails' do
          expected_error_msg = <<-EXPECTED.strip
Unable to process links for deployment. Errors are:
  - Can't find deployment non-existent
          EXPECTED

          expect {
            links_resolver.resolve(api_server_instance_group)
          }.to raise_error(expected_error_msg)
        end
      end
    end

    context 'when provided link type does not match required link type' do
      let(:links) { {'db' => {"from" => 'db', 'deployment' => 'fake-deployment'}} }

      let(:consumes_links) { [{'name' => 'db', 'type' => 'other'}] }
      let(:provided_links) { [{name: "db", type: "db"}] } # name and type is implicitly db

      it 'fails to find link' do
        expect {
          links_resolver.resolve(api_server_instance_group)
        }.to raise_error Bosh::Director::DeploymentInvalidLink,
          "Cannot resolve link path 'fake-deployment.mysql.mysql-template.db' " +
            "required for link 'db' in instance group 'api-server' on job 'api-server-template'"
      end
    end

    context 'when provided link name matches links name' do
      let (:links) { {'backup_db' => {"from" => 'db'}} }

      let(:consumes_links) { [{'name' => 'backup_db', 'type' => 'db'}] }
      let(:provided_links) { [{name: "db", type: "db", properties: ['mysql']}] }

      it 'adds link to job' do
        links_resolver.resolve(api_server_instance_group)
        instance1 = Bosh::Director::Models::Instance.where(job: 'mysql', index: 0).first
        instance2 = Bosh::Director::Models::Instance.where(job: 'mysql', index: 1).first

        link_spec = {
          'deployment_name' => api_server_instance_group.deployment_name,
          'domain' => 'bosh',
          'default_network' => 'fake-manual-network',
          'source_instance_group' => 'mysql',
          'networks' => ['fake-manual-network', 'fake-dynamic-network'],
          "properties" => {"mysql" => nil},
          'instances' => [
            {
              'index' => 0,
              "bootstrap" => true,
              'id' => instance1.uuid,
              'az' => nil,
              'address' => '127.0.0.3',
            },
            {
              'index' => 1,
              "bootstrap" => false,
              'id' => instance2.uuid,
              'az' => nil,
              'address' => '127.0.0.4',
            }
          ]
        }

        links_hash = {"api-server-template" => {"backup_db" => link_spec}}

        expect(api_server_instance_group.resolved_links).to eq(links_hash)
      end
    end

    context 'when link source is does not specify deployment name' do
      let(:links) { {'db' => {"from" => 'db'}} }

      it 'defaults to current deployment' do
        links_resolver.resolve(api_server_instance_group)
        link_spec = api_server_instance_group.resolved_links['api-server-template']['db']
        expect(link_spec['instances'].first['name']).to eq('mysql')
        expect(link_spec['deployment_name']).to eq(api_server_instance_group.deployment_name)
        expect(link_spec['source_instance_group']).to eq('mysql')
      end
    end

    context 'link source network and ip_addresses' do
      let(:links) { {'db' => {'from' => 'db', 'network' => 'fake-dynamic-network'}} }
      let(:link_lookup) { instance_double(Bosh::Director::DeploymentPlan::PlannerLinkLookup) }

      before do
        allow(link_lookup).to receive(:find_link_spec).and_return({'instances' => []})
      end

      context 'when link source specifies network' do
        it 'respects value passed' do
          expect(Bosh::Director::DeploymentPlan::LinkLookupFactory).to receive(:create).exactly(2).times.with(
            anything,
            anything,
            anything,
            {:preferred_network_name => 'fake-dynamic-network', :global_use_dns_entry => false, :link_use_ip_address => nil}
          ).and_return(link_lookup)

          links_resolver.resolve(api_server_instance_group)
        end

        context 'when not specified' do
          let(:links) { {'db' => {'from' => 'db'}} }

          it 'defaults to nil' do
            expect(Bosh::Director::DeploymentPlan::LinkLookupFactory).to receive(:create).exactly(2).times.with(
              anything,
              anything,
              anything,
              {:preferred_network_name => nil, :global_use_dns_entry => false, :link_use_ip_address => nil}
            ).and_return(link_lookup)

            links_resolver.resolve(api_server_instance_group)
          end
        end
      end

      context 'use_dns_addresses director and deployment level flag' do
        context 'when deployment use_dns_addresses is NOT defined' do
          context 'when director use_dns_addresses flag is FALSE' do
            before do
              allow(Bosh::Director::Config).to receive(:local_dns_use_dns_addresses?).and_return(false)
            end

            let(:links) { {'db' => {'from' => 'db'}} }

            it 'it passes global_use_dns_entry as false' do
              expect(Bosh::Director::DeploymentPlan::LinkLookupFactory).to receive(:create).exactly(2).times.with(
                anything,
                anything,
                anything,
                {:preferred_network_name => nil, :global_use_dns_entry => false, :link_use_ip_address => nil}
              ).and_return(link_lookup)

              links_resolver.resolve(api_server_instance_group)
            end
          end

          context 'when director use_dns_addresses flag is TRUE' do
            before do
              allow(Bosh::Director::Config).to receive(:local_dns_use_dns_addresses?).and_return(true)
            end

            let(:links) { {'db' => {'from' => 'db'}} }

            it 'it passes global_use_dns_entry as true' do
              expect(Bosh::Director::DeploymentPlan::LinkLookupFactory).to receive(:create).exactly(2).times.with(
                anything,
                anything,
                anything,
                {:preferred_network_name => nil, :global_use_dns_entry => true, :link_use_ip_address => nil}
              ).and_return(link_lookup)

              links_resolver.resolve(api_server_instance_group)
            end
          end
        end

        context 'when deployment use_dns_addresses is defined' do
          context 'when it is FALSE' do
            before do
              deployment_manifest['features'] = {'use_dns_addresses' => false}
            end

            let(:links) { {'db' => {'from' => 'db'}} }

            it 'it passes global_use_dns_entry as false' do
              expect(Bosh::Director::DeploymentPlan::LinkLookupFactory).to receive(:create).exactly(2).times.with(
                anything,
                anything,
                anything,
                {:preferred_network_name => nil, :global_use_dns_entry => false, :link_use_ip_address => nil}
              ).and_return(link_lookup)

              links_resolver.resolve(api_server_instance_group)
            end
          end

          context 'when it is TRUE' do
            before do
              deployment_manifest['features'] = {'use_dns_addresses' => true}
            end

            let(:links) { {'db' => {'from' => 'db'}} }

            it 'it passes global_use_dns_entry as TRUE' do
              expect(Bosh::Director::DeploymentPlan::LinkLookupFactory).to receive(:create).exactly(2).times.with(
                anything,
                anything,
                anything,
                {:preferred_network_name => nil, :global_use_dns_entry => true, :link_use_ip_address => nil}
              ).and_return(link_lookup)

              links_resolver.resolve(api_server_instance_group)
            end
          end
        end
      end

      context 'ip_addresses' do
        context 'when ip_addresses key on the consumed link is not set' do
          let(:links) { {'db' => {'from' => 'db'}} }

          it 'it sets link_use_ip_address to nil' do
            expect(Bosh::Director::DeploymentPlan::LinkLookupFactory).to receive(:create).exactly(2).times.with(
              anything,
              anything,
              anything,
              {:preferred_network_name => nil, :global_use_dns_entry => false, :link_use_ip_address => nil}
            ).and_return(link_lookup)

            links_resolver.resolve(api_server_instance_group)
          end
        end

        context 'when ip_addresses key on the consumed link is FALSE' do
          let(:links) { {'db' => {'from' => 'db', 'ip_addresses' => false }} }
          it 'it sets link_use_ip_address to false' do
            expect(Bosh::Director::DeploymentPlan::LinkLookupFactory).to receive(:create).exactly(2).times.with(
              anything,
              anything,
              anything,
              {:preferred_network_name => nil, :global_use_dns_entry => false, :link_use_ip_address => false}
            ).and_return(link_lookup)

            links_resolver.resolve(api_server_instance_group)
          end
        end

        context 'when ip_addresses key on the consumed link is TRUE' do
          let(:links) { {'db' => {'from' => 'db', 'ip_addresses' => true }} }
          it 'it sets link_use_ip_address to true' do
            expect(Bosh::Director::DeploymentPlan::LinkLookupFactory).to receive(:create).exactly(2).times.with(
              anything,
              anything,
              anything,
              {:preferred_network_name => nil, :global_use_dns_entry => false, :link_use_ip_address => true}
            ).and_return(link_lookup)

            links_resolver.resolve(api_server_instance_group)
          end
        end
      end
    end

    context 'when links source is not provided' do
      let(:links) { {'db' => {"from" => 'db', 'deployment' => 'non-existant'}} }

      it 'fails' do
        expected_error_msg = <<-EXPECTED.strip
Unable to process links for deployment. Errors are:
  - Can't find deployment non-existant
        EXPECTED

        expect {
          links_resolver.resolve(api_server_instance_group)
        }.to raise_error(expected_error_msg)
      end
    end

    context 'when required link is not specified in manifest' do
      let(:links) { {'other' => {"from" => 'c'}} }
      let(:consumes_links) { [{'name' => 'other', 'type' => 'db'}] }

      it 'fails' do
        expected_error_msg = <<-EXPECTED.strip
Unable to process links for deployment. Errors are:
  - Can't resolve link 'c' in instance group 'api-server' on job 'api-server-template' in deployment 'fake-deployment'.
        EXPECTED

        expect {
          links_resolver.resolve(api_server_instance_group)
        }.to raise_error(expected_error_msg)
      end
    end

    context 'when link specified in manifest is not required' do

      let(:links) { {'db' => {"from" => 'db'}} }

      let(:consumes_links) { [] }
      let(:provided_links) { [{'name' => 'db', 'type' => 'db'}] }

      it 'raises unused link error' do
        expect {
          links_resolver.resolve(api_server_instance_group)
        }.to raise_error Bosh::Director::UnusedProvidedLink,
          "Job 'api-server-template' in instance group 'api-server' specifies link 'db', " +
            "but the release job does not consume it."
      end
    end

    context 'when there is a cloud config' do
      let(:deployment_plan) do
        planner_factory = Bosh::Director::DeploymentPlan::PlannerFactory.create(logger)
        manifest = Bosh::Director::Manifest.load_from_hash(deployment_manifest, cloud_config, [], {:resolve_interpolation => false})

        planner = planner_factory.create_from_manifest(manifest, cloud_config, [], {})
        Bosh::Director::DeploymentPlan::Assembler.create(planner).bind_models
        planner
      end

      let(:links) { {'db' => {'from' => 'db'}} }

      let(:deployment_manifest) { generate_manifest_without_cloud_config('fake-deployment', links, ['127.0.0.3', '127.0.0.4']) }

      let(:cloud_config) do
        Bosh::Director::Models::CloudConfig.make(raw_manifest: {
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
        })
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
              'templates' => [
                {'name' => 'api-server-template', 'release' => 'fake-release', 'consumes' => links}
              ],
              'resource_pool' => 'fake-resource-pool',
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
              'templates' => [
                {'name' => 'mysql-template',
                  'release' => 'fake-release',
                  'provides' => {'db' => {'as' => 'db'}},
                  'properties' => {'mysql' => nil}
                }
              ],
              'resource_pool' => 'fake-resource-pool',
              'instances' => 2,
              'azs' => ['az1'],
              'networks' => [
                {
                  'name' => 'fake-manual-network',
                  'static_ips' => ['127.0.0.3', '127.0.0.4'],
                  'default' => ['dns', 'gateway'],

                },
                {
                  'name' => 'fake-dynamic-network',
                }
              ],
            },
          ],
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
          'source_instance_group' => 'mysql',
          'networks' => ['fake-manual-network', 'fake-dynamic-network'],
          "properties" => {"mysql" => nil},
          'instances' => [
            {
              'index' => 0,
              "bootstrap" => true,
              'id' => instance1.uuid,
              'az' => 'az1',
              'address' => '127.0.0.3',
            },
            {
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
