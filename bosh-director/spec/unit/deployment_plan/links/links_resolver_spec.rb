require 'spec_helper'

describe Bosh::Director::DeploymentPlan::LinksResolver do
  subject(:links_resolver) { described_class.new(deployment_plan, logger) }

  let(:deployment_plan) do
    planner_factory = Bosh::Director::DeploymentPlan::PlannerFactory.create(logger)
    manifest = Bosh::Director::Manifest.new(deployment_manifest, nil, nil)
    planner = planner_factory.create_from_manifest(manifest, nil, nil, {})
    planner.bind_models
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
             'provides' => {'db' => {'as' => 'db', 'name' =>'db', 'type'=>'db'}},
             "properties" => {'mysql' => nil}
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

  let(:api_server_job) do
    deployment_plan.job('api-server')
  end

  before do
    fake_locks

    Bosh::Director::Models::Stemcell.make(name: 'fake-stemcell', version: 'fake-stemcell-version')

    allow(Bosh::Director::Config).to receive(:cloud).and_return(nil)
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
                                                           properties: {mysql: {description:'some description'}},
                                                           release_id: 1)
    version.add_template(template_model)

    deployment_model = Bosh::Director::Models::Deployment.make(name: 'fake-deployment',
                                                               link_spec_json: "{\"mysql\":{\"mysql-template\":{\"db\":{\"name\":\"db\",\"type\":\"db\"}}}}")
    version.add_deployment(deployment_model)

    deployment_model = Bosh::Director::Models::Deployment.make(name: 'other-deployment',
                                                               manifest: deployment_manifest.to_json,
                                                               link_spec_json: "{\"mysql\":{\"mysql-template\":{\"db\":{\"name\":\"db\",\"type\":\"db\"}}}}")
    version.add_deployment(deployment_model)
  end

  let(:consumes_links) { [{name: "db", type: "db"}] }
  let(:provided_links) { [{name: "db", type: "db", shared: true, properties: ['mysql']}] }

  describe '#resolve' do
    context 'when job consumes link from the same deployment' do
      context 'when link source is provided by some job' do
        let(:links) { {'db' => {"from" => 'db'}} }

        it 'adds link to job' do
          links_resolver.resolve(api_server_job)
          instance1 = Bosh::Director::Models::Instance.where(job: 'mysql', index: 0).first
          instance2 = Bosh::Director::Models::Instance.where(job: 'mysql', index: 1).first

          expect(api_server_job.link_spec).to eq(
            {"db" => {"networks" => ["fake-manual-network", "fake-dynamic-network"],
                      "properties" => {"mysql" => nil},
                      "instances" => [
                          {"name" => "mysql",
                           "index" => 0,
                           "bootstrap" => true,
                           "id" => instance1.uuid,
                           "az" => nil,
                           "address" => "127.0.0.3",
                           },

                          {"name" => "mysql",
                           "index" => 1,
                           "bootstrap" => false,
                           "id" => instance2.uuid,
                           "az" => nil, "address" => "127.0.0.4",
                           }
                      ]
            }})
        end
      end
    end

    context 'when job consumes link from another deployment' do
      let(:links) { {'db' => {"from" => 'db', 'deployment' => 'other-deployment'}} }

      context 'when another deployment has link source' do
        before do
          other_deployment_manifest = generate_deployment_manifest('other-deployment', links, ['127.0.0.4', '127.0.0.5'])

          planner_factory = Bosh::Director::DeploymentPlan::PlannerFactory.create(logger)
          manifest = Bosh::Director::Manifest.new(other_deployment_manifest, nil, nil)
          deployment_plan = planner_factory.create_from_manifest(manifest, nil, nil, {})
          deployment_plan.bind_models

          links_resolver = described_class.new(deployment_plan, logger)
          mysql_job = deployment_plan.job('mysql')
          links_resolver.resolve(mysql_job)

          deployment_plan.persist_updates!
        end

        it 'returns link from another deployment' do
          links_resolver.resolve(api_server_job)
          instance1 = Bosh::Director::Models::Instance.where(job: 'mysql', index: 0).first
          instance2 = Bosh::Director::Models::Instance.where(job: 'mysql', index: 1).first

          expect(api_server_job.link_spec).to eq({
                'db' => {
                  'networks' => ['fake-manual-network', 'fake-dynamic-network'],
                  "properties"=>{"mysql"=>nil},
                  'instances' => [
                    {
                      'name' => 'mysql',
                      'index' => 0,
                      "bootstrap" => true,
                      'id' => instance1.uuid,
                      'az' => nil,
                      'address' => '127.0.0.4'
                    },
                    {
                      'name' => 'mysql',
                      'index' => 1,
                      "bootstrap" => false,
                      'id' => instance2.uuid,
                      'az' => nil,
                      'address' => '127.0.0.5'
                    }
                  ]
                }
              })
        end
      end

      context 'when another deployment does not have link source' do
        let(:links) { {'db' => {"from" => 'db', 'deployment' => 'non-existent'}} }

        it 'fails' do
          expect {
            links_resolver.resolve(api_server_job)
          }.to raise_error("Unable to process links for deployment. Errors are:
   - \"Can't find deployment non-existent\"")
        end
      end
    end

    context 'when provided link type does not match required link type' do
      let(:links) { {'db' => {"from" => 'db', 'deployment' => 'fake-deployment'}} }

      let(:consumes_links) { [{'name' => 'db', 'type' => 'other'}] }
      let(:provided_links) { [{name: "db", type: "db"}] } # name and type is implicitly db

      it 'fails to find link' do
        expect {
          links_resolver.resolve(api_server_job)
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
        links_resolver.resolve(api_server_job)
        instance1 = Bosh::Director::Models::Instance.where(job: 'mysql', index: 0).first
        instance2 = Bosh::Director::Models::Instance.where(job: 'mysql', index: 1).first

        expect(api_server_job.link_spec).to eq({
              'backup_db' => {
                'networks' => ['fake-manual-network', 'fake-dynamic-network'],
                "properties"=>{"mysql"=>nil},
                'instances' => [
                  {
                    'name' => 'mysql',
                    'index' => 0,
                    "bootstrap" => true,
                    'id' => instance1.uuid,
                    'az' => nil,
                    'address' => '127.0.0.3',
                  },
                  {
                    'name' => 'mysql',
                    'index' => 1,
                    "bootstrap" => false,
                    'id' => instance2.uuid,
                    'az' => nil,
                    'address' => '127.0.0.4',
                  }
                ]
              }
            })
      end
    end

    context 'when link source is does not specify deployment name' do
      let(:links) { {'db' => {"from" => 'db'}} }

      it 'defaults to current deployment' do
        links_resolver.resolve(api_server_job)
        expect(api_server_job.link_spec['db']['instances'].first['name']).to eq('mysql')
      end
    end

    context 'when links source is not provided' do
      let(:links) { {'db' => {"from" => 'db', 'deployment' => 'non-existant'}} }

      it 'fails' do
        expect {
          links_resolver.resolve(api_server_job)
        }.to raise_error("Unable to process links for deployment. Errors are:
   - \"Can't find deployment non-existant\"")
      end
    end

    context 'when required link is not specified in manifest' do
      let(:links) { {'other' => {"from" => 'c'}} }

      let(:consumes_links) { [{'name' => 'other', 'type' => 'db'}] }
      it 'fails' do
        expect {
          links_resolver.resolve(api_server_job)
        }.to raise_error("Unable to process links for deployment. Errors are:
   - \"Can't resolve link 'c' in instance group 'api-server' on job 'api-server-template' in deployment 'fake-deployment'.\"")
      end
    end

    context 'when link specified in manifest is not required' do

      let(:links) { {'db' => {"from" => 'db'}} }

      let(:consumes_links) { [] }
      let(:provided_links) { [{'name'=>'db', 'type'=>'db'}] }

      it 'raises unused link error' do
        expect {
          links_resolver.resolve(api_server_job)
        }.to raise_error Bosh::Director::UnusedProvidedLink,
            "Job 'api-server-template' in instance group 'api-server' specifies link 'db', " +
              "but the release job does not consume it."
      end
    end

    context 'when there is a cloud config' do
      let(:deployment_plan) do
        planner_factory = Bosh::Director::DeploymentPlan::PlannerFactory.create(logger)
        manifest = Bosh::Director::Manifest.new(deployment_manifest, cloud_config.manifest, nil)
        planner = planner_factory.create_from_manifest(manifest, cloud_config, nil, {})
        planner.bind_models
        planner
      end

      let(:links) { {'db' => {'from'=>'db'}} }

      let(:deployment_manifest) { generate_manifest_without_cloud_config('fake-deployment', links, ['127.0.0.3', '127.0.0.4']) }

      let(:cloud_config) do
        Bosh::Director::Models::CloudConfig.make(manifest: {
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

        links_resolver.resolve(api_server_job)
        instance1 = Bosh::Director::Models::Instance.where(job: 'mysql', index: 0).first
        instance2 = Bosh::Director::Models::Instance.where(job: 'mysql', index: 1).first
        expect(api_server_job.link_spec).to eq({
              'db' => {
                'networks' => ['fake-manual-network', 'fake-dynamic-network'],
                "properties"=>{"mysql"=>nil},
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
            })
      end
    end
  end
end
