require 'spec_helper'

describe 'Links', type: :integration do
  with_reset_sandbox_before_each

  def upload_links_release
    FileUtils.cp_r(LINKS_RELEASE_TEMPLATE, ClientSandbox.links_release_dir, :preserve => true)
    bosh_runner.run_in_dir('create release --force', ClientSandbox.links_release_dir)
    bosh_runner.run_in_dir('upload release', ClientSandbox.links_release_dir)
  end

  def find_vm(vms, job_name, index)
    vms.find do |vm|
      vm.job_name == job_name && vm.index == index
    end
  end

  def should_contain_network_for_job(job, template, pattern)
    my_api_vm = director.vm(job, '0', deployment: 'simple')
    template = YAML.load(my_api_vm.read_job_template(template, 'config.yml'))

    template['databases'].each do |_, database|
      database.each do |node|
        node['networks'].each do |network|
          expect(network['address']).to match(pattern)
        end
      end
    end
  end

  let(:cloud_config) do
    cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
    cloud_config_hash['azs'] = [{ 'name' => 'z1' }]
    cloud_config_hash['networks'].first['subnets'].first['static'] = ['192.168.1.10', '192.168.1.11', '192.168.1.12', '192.168.1.13']
    cloud_config_hash['networks'].first['subnets'].first['az'] = 'z1'
    cloud_config_hash['compilation']['az'] = 'z1'
    cloud_config_hash['networks'] << {
        'name' => 'dynamic-network',
        'type' => 'dynamic',
        'subnets' => [{'az' => 'z1'}]
    }

    cloud_config_hash
  end

  before do
    target_and_login
    upload_links_release
    upload_stemcell

    upload_cloud_config(cloud_config_hash: cloud_config)
  end

  context 'when job requires link' do
    let(:implied_job_spec) do
      job_spec = Bosh::Spec::Deployments.simple_job(
          name: 'my_api',
          templates: [{'name' => 'api_server'}],
          instances: 1
      )
      job_spec['azs'] = ['z1']
      job_spec
    end

    let(:api_job_spec) do
      job_spec = Bosh::Spec::Deployments.simple_job(
        name: 'my_api',
        templates: [{'name' => 'api_server', 'consumes' => links}],
        instances: 1
      )
      job_spec['azs'] = ['z1']
      job_spec
    end

    let(:mysql_job_spec) do
      job_spec = Bosh::Spec::Deployments.simple_job(
        name: 'mysql',
        templates: [{'name' => 'database'}],
        instances: 2,
        static_ips: ['192.168.1.10', '192.168.1.11']
      )
      job_spec['azs'] = ['z1']
      job_spec['networks'] << {
        'name' => 'dynamic-network',
        'default' => ['dns', 'gateway']
      }
      job_spec
    end

    let(:postgres_job_spec) do
      job_spec = Bosh::Spec::Deployments.simple_job(
        name: 'postgres',
        templates: [{'name' => 'backup_database'}],
        instances: 1,
        static_ips: ['192.168.1.12']
      )
      job_spec['azs'] = ['z1']
      job_spec
    end

    let(:aliased_job_spec) do
      job_spec = Bosh::Spec::Deployments.simple_job(
          name: 'aliased_postgres',
          templates: [{'name' => 'backup_database', 'provides' => {'backup_db' => {'as' => 'link_alias'}}}],
          instances: 1,
      )
      job_spec['azs'] = ['z1']
      job_spec
    end

    let(:mongo_db_spec)do
      job_spec = Bosh::Spec::Deployments.simple_job(
        name: 'mongo',
        templates: [{'name' => 'mongo_db'}],
        instances: 1,
        static_ips: ['192.168.1.13']
      )
      job_spec['azs'] = ['z1']
      job_spec
    end

    let(:manifest) do
      manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
      manifest['jobs'] = [api_job_spec, mysql_job_spec, postgres_job_spec]
      manifest
    end

    context 'when link is provided' do
      let(:links) do
        {
          'db' => {'from' => 'simple.db'},
          'backup_db' => {'from' => 'simple.backup_db'}
        }
      end

      it 'renders link data in job template' do
        deploy_simple_manifest(manifest_hash: manifest)

        vms = director.vms
        link_vm = find_vm(vms, 'my_api', '0')
        mysql_0_vm = find_vm(vms, 'mysql', '0')
        mysql_1_vm = find_vm(vms, 'mysql', '1')

        template = YAML.load(link_vm.read_job_template('api_server', 'config.yml'))

        expect(template['databases']['main'].size).to eq(2)
        expect(template['databases']['main']).to contain_exactly(
            {
              'name' => 'mysql',
              'index' => 0,
              'networks' => [
                {
                  'name' => 'dynamic-network',
                  'address' => "#{mysql_0_vm.instance_uuid}.mysql.dynamic-network.simple.bosh"
                }
              ]
            },
            {
              'name' => 'mysql',
              'index' => 1,
              'networks' => [
                {
                  'name' => 'dynamic-network',
                  'address' => "#{mysql_1_vm.instance_uuid}.mysql.dynamic-network.simple.bosh"
                }
              ]
            }
          )

        expect(template['databases']['backup']).to contain_exactly(
            {
              'name' => 'postgres',
              'az' => 'z1',
              'index' => 0,
              'networks' => [
                {
                  'name' => 'a',
                  'address' => '192.168.1.12',
                }
              ]
            }
          )
      end
    end

    context 'when exporting a release with templates that have links' do

      let(:manifest) do
        manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
        manifest['jobs'] = [mongo_db_spec]

        # We manually change the deployment manifest release version, beacuse of w weird issue where
        # the uploaded release version is `0+dev.1` and the release version in the deployment manifest
        # is `0.1-dev`
        manifest['releases'][0]['version'] = '0+dev.1'

        manifest
      end

      it 'should successfully compile a release without complaininfg about missing links' do
        deploy_simple_manifest(manifest_hash: manifest)
        out = bosh_runner.run("export release bosh-release/0+dev.1 toronto-os/1")

        expect(out).to_not include('Started compiling packages > pkg_1')
        expect(out).to include('Started compiling packages > pkg_2/4b74be7d5aa14487c7f7b0d4516875f7c0eeb010. Done')
        expect(out).to include('Started compiling packages > pkg_3_depends_on_2/413e3e9177f0037b1882d19fb6b377b5b715be1c. Done')

        expect(out).to include('Started copying packages')
        expect(out).to include('Started copying packages > pkg_1/16b4c8ef1574b3f98303307caad40227c208371f. Done')
        expect(out).to include('Started copying packages > pkg_2/4b74be7d5aa14487c7f7b0d4516875f7c0eeb010. Done')
        expect(out).to include('Started copying packages > pkg_3_depends_on_2/413e3e9177f0037b1882d19fb6b377b5b715be1c. Done')

        expect(out).to include('Started copying jobs')
        expect(out).to include('Started copying jobs > api_server/2b09d03e6557e34d9f2fde8246a4b479e71e4659. Done')
        expect(out).to include('Started copying jobs > backup_database/2ea09882747364709dad9f45267965ac176ae5ad. Done')
        expect(out).to include('Started copying jobs > database/a9f952f94a82c13a3129ac481030f704a33d027f. Done')
        expect(out).to include('Started copying jobs > mongo_db/1a57f0be3eb19e263261536693db0d5a521261a6. Done')
        expect(out).to include('Started copying jobs > node/ec75fb84ede26871bd7d8dc98bf2d3122a447eed. Done')
        expect(out).to include('Done copying jobs')

        expect(out).to include('Exported release `bosh-release/0+dev.1` for `toronto-os/1`')
      end
    end

    context 'when consumes link is renamed by from key' do
      let(:manifest) do
        manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
        manifest['jobs'] = [api_job_spec, mongo_db_spec, mysql_job_spec]
        manifest
      end

      let(:links) do
        {
          'db' => {'from'=>'simple.db'},
          'backup_db' => {'from' => 'simple.read_only_db'},
        }
      end

      it 'renders link data in job template' do
        deploy_simple_manifest(manifest_hash: manifest)

        link_vm = director.vm('my_api', '0')
        template = YAML.load(link_vm.read_job_template('api_server', 'config.yml'))

        expect(template['databases']['backup'].size).to eq(1)
        expect(template['databases']['backup']).to contain_exactly(
            {
              'name' => 'mongo',
              'index' => 0,
              'az' => 'z1',
              'networks' => [
                {
                  'name' => 'a',
                  'address' => '192.168.1.13',
                }
              ]
            }
          )
      end
    end

    context 'deployment job does not have templates' do
      let(:first_node_job_spec) do
        job_spec = Bosh::Spec::Deployments.simple_job(
            name: 'first_node',
            templates: [],
            instances: 1,
            static_ips: ['192.168.1.10']
        )
        job_spec['azs'] = ['z1']
        job_spec
      end


      let(:manifest) do
        manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
        manifest['jobs'] = [first_node_job_spec]
        manifest
      end

      it 'renders link data in job template' do
        deploy_simple_manifest(manifest_hash: manifest)
      end
    end


    context 'when release job requires and provides same link' do
      let(:first_node_job_spec) do
        job_spec = Bosh::Spec::Deployments.simple_job(
          name: 'first_node',
          templates: [{'name' => 'node', 'consumes' => first_node_links}],
          instances: 1,
          static_ips: ['192.168.1.10']
        )
        job_spec['azs'] = ['z1']
        job_spec
      end

      let(:first_node_links) do
        {
          'node1' => {'from' => 'simple.node1'},
          'node2' => {'from' => 'simple.node2'}
        }
      end

      let(:second_node_job_spec) do
        job_spec = Bosh::Spec::Deployments.simple_job(
          name: 'second_node',
          templates: [{'name' => 'node', 'consumes' => second_node_links}],
          instances: 1,
          static_ips: ['192.168.1.11']
        )
        job_spec['azs'] = ['z1']
        job_spec
      end
      let(:second_node_links) do
        {
          'node1' => {'from' => 'simple.node1'},
          'node2' => {'from' => 'simple.node2'}
        }
      end

      let(:manifest) do
        manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
        manifest['jobs'] = [first_node_job_spec, second_node_job_spec]
        manifest
      end

      it 'renders link data in job template' do
        _, exit_code = deploy_simple_manifest(manifest_hash: manifest, failure_expected: true, return_exit_code: true)
        expect(exit_code).not_to eq(0)
      end
    end

    context 'when provide and consume links are set in spec, but only implied by deployment manifest' do
      let(:manifest) do
        manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
        manifest['jobs'] = [implied_job_spec, postgres_job_spec]
        manifest
      end

      it 'renders link data in job template' do
        deploy_simple_manifest(manifest_hash: manifest)

        link_vm = director.vm('my_api', '0')
        template = YAML.load(link_vm.read_job_template('api_server', 'config.yml'))

        expect(template['databases']['main'].size).to eq(1)
        expect(template['databases']['main']).to contain_exactly(
             {
                 'name' => 'postgres',
                 'index' => 0,
                 'networks' => [
                     {
                         'name' => 'a',
                         'address' => '192.168.1.12',
                     }
                 ]
             }
         )

        expect(template['databases']['backup'].size).to eq(1)
        expect(template['databases']['backup']).to contain_exactly(
                                                     {
                                                         'name' => 'postgres',
                                                         'index' => 0,
                                                         'az' => 'z1',
                                                         'networks' => [
                                                             {
                                                                 'name' => 'a',
                                                                 'address' => '192.168.1.12',
                                                             }
                                                         ]
                                                     }
                                                 )
      end
    end

    context 'when provide and consume links are set in spec, and implied by deployment manifest, but there are multiple provide links with same type' do
      let(:manifest) do
        manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
        manifest['jobs'] = [implied_job_spec, postgres_job_spec, mysql_job_spec]
        manifest
      end

      it 'raises error before deploying vms' do
        _, exit_code = deploy_simple_manifest(manifest_hash: manifest, failure_expected: true, return_exit_code: true)
        expect(exit_code).not_to eq(0)
        expect(director.vms('simple')).to eq([])
      end
    end

    context 'when provide link is aliased using "as", and the consume link references the new alias' do
      let(:manifest) do
        manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
        manifest['jobs'] = [api_job_spec, aliased_job_spec]
        manifest
      end

      let(:links) do
        {
            'db' => {'from'=>'link_alias'},
            'backup_db' => {'from' => 'simple.link_alias'},
        }
      end

      it 'renders link data in job template' do
        deploy_simple_manifest(manifest_hash: manifest)

        link_vm = director.vm('my_api', '0')
        template = YAML.load(link_vm.read_job_template('api_server', 'config.yml'))

        expect(template['databases']['main'].size).to eq(1)
        expect(template['databases']['main']).to contain_exactly(
                                                     {
                                                         'name' => 'aliased_postgres',
                                                         'index' => 0,
                                                         'networks' => [
                                                             {
                                                                 'name' => 'a',
                                                                 'address' => '192.168.1.3',
                                                             }
                                                         ]
                                                     }
                                                 )
      end
    end

    context 'when provide link is aliased using "as", and the consume link references the old name' do
      let(:manifest) do
        manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
        manifest['jobs'] = [api_job_spec, aliased_job_spec]
        manifest
      end

      let(:links) do
        {
            'db' => {'from'=>'backup_db'},
            'backup_db' => {'from' => 'simple.backup_db'},
        }
      end

      it 'throws an error before deploying vms' do
        _, exit_code = deploy_simple_manifest(manifest_hash: manifest, failure_expected: true, return_exit_code: true)
        expect(exit_code).not_to eq(0)
        expect(director.vms('simple')).to eq([])
      end
    end

    context 'when deployment includes a migrated job which also provides or consumes links' do
      let(:links) do
        {
            'db' => {'from'=>'link_alias'},
            'backup_db' => {'from' => 'simple.link_alias'},
        }
      end
      let(:manifest) do
        manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
        manifest['jobs'] = [api_job_spec, aliased_job_spec]
        manifest
      end

      let(:new_api_job_spec) do
        job_spec = Bosh::Spec::Deployments.simple_job(
            name: 'new_api_job',
            templates: [{'name' => 'api_server', 'consumes' => links}],
            instances: 1,
            migrated_from: ['name' => 'my_api']
        )
        job_spec['azs'] = ['z1']
        job_spec
      end

      let(:new_aliased_job_spec) do
        job_spec = Bosh::Spec::Deployments.simple_job(
            name: 'new_aliased_job',
            templates: [{'name' => 'backup_database', 'provides' => {'backup_db' => {'as' => 'link_alias'}}}],
            instances: 1,
            migrated_from: ['name' => 'aliased_postgres']
        )
        job_spec['azs'] = ['z1']
        job_spec
      end

      it 'deploys migrated_from jobs' do
        deploy_simple_manifest(manifest_hash: manifest)
        manifest['jobs'] = [new_api_job_spec, new_aliased_job_spec]
        deploy_simple_manifest(manifest_hash: manifest)

        link_vm = director.vm('new_api_job', '0')
        template = YAML.load(link_vm.read_job_template('api_server', 'config.yml'))

        expect(template['databases']['main'].size).to eq(1)
        expect(template['databases']['main']).to contain_exactly(
                                                     {
                                                         'name' => 'new_aliased_job',
                                                         'index' => 0,
                                                         'networks' => [
                                                             {
                                                                 'name' => 'a',
                                                                 'address' => '192.168.1.5',
                                                             }
                                                         ]
                                                     }
                                                 )
      end

    end


    context 'when link is broken' do
      let(:manifest) do
        manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
        manifest['jobs'] = [first_node_job_spec, second_node_job_spec]
        manifest
      end

      let(:first_node_job_spec) do
        Bosh::Spec::Deployments.simple_job(
          name: 'first_node',
          templates: [{'name' => 'node', 'consumes' => first_node_links}],
          instances: 1,
          static_ips: ['192.168.1.10']
        )
      end

      let(:first_node_links) do
        {
          'node1' => {'from' => 'simple.node1'},
          'node2' => {'from' => 'simple.node2'}
        }
      end

      let(:second_node_job_spec) do
        Bosh::Spec::Deployments.simple_job(
          name: 'second_node',
          templates: [{'name' => 'node', 'consumes' => second_node_links}],
          instances: 1,
          static_ips: ['192.168.1.11']
        )
      end

      let(:second_node_links) do
        {
          'node1' => {'from' => 'broken.broken'},
          'node2' => {'from' =>'other.blah'}
        }
      end

      it 'catches broken link before updating vms' do
        _, exit_code = deploy_simple_manifest(manifest_hash: manifest, failure_expected: true, return_exit_code: true)
        expect(exit_code).not_to eq(0)
        expect(director.vms('simple')).to eq([])
      end
  end

   context 'when link references another deployment' do
      let(:first_deployment_job_spec) do
        job_spec = Bosh::Spec::Deployments.simple_job(
          name: 'first_deployment_node',
          templates: [{'name' => 'node', 'consumes' => first_deployment_links}],
          instances: 1,
          static_ips: ['192.168.1.10']
        )
        job_spec['azs'] = ['z1']
        job_spec
      end

      let(:first_deployment_links) do
        {
          'node1' => {'from' => 'first.node1'},
          'node2' => {'from' => 'first.node2'}
        }
      end

      let(:first_manifest) do
        manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
        manifest['name'] = 'first'
        manifest['jobs'] = [first_deployment_job_spec]
        manifest
      end

      let(:second_deployment_job_spec) do
        job_spec = Bosh::Spec::Deployments.simple_job(
          name: 'second_deployment_node',
          templates: [{'name' => 'node', 'consumes' => second_deployment_links}],
          instances: 1,
          static_ips: ['192.168.1.11']
        )
        job_spec['azs'] = ['z1']
        job_spec
      end

      let(:second_deployment_links) do
        {
          'node1' => {'from' => 'first.node1'},
          'node2' => {'from' => 'second.node2'}
        }
      end

      let(:second_manifest) do
        manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
        manifest['name'] = 'second'
        manifest['jobs'] = [second_deployment_job_spec]
        manifest
      end

      it 'can find it' do
        deploy_simple_manifest(manifest_hash: first_manifest)
        deploy_simple_manifest(manifest_hash: second_manifest)

        second_deployment_vm = director.vm('second_deployment_node', '0', deployment: 'second')
        second_deployment_template = YAML.load(second_deployment_vm.read_job_template('node', 'config.yml'))

        expect(second_deployment_template['nodes']['node1_ips']).to eq(['192.168.1.10'])
        expect(second_deployment_template['nodes']['node2_ips']).to eq(['192.168.1.11'])
      end
    end

    describe 'network resolution' do

      context 'when user specifies a network in consumes' do

        let(:links) do
          {
              'db' => {'from' => 'simple.db', 'network' => 'b'},
              'backup_db' => {'from' => 'simple.backup_db', 'network' => 'b'}
          }
        end

        it 'overrides the default network' do
          cloud_config['networks'] << {
              'name' => 'b',
              'type' => 'dynamic',
              'subnets' => [{'az' => 'z1'}]
          }

          mysql_job_spec['networks'] << {
              'name' => 'b'
          }

          postgres_job_spec['networks'] << {
              'name' => 'dynamic-network',
              'default' => ['dns', 'gateway']
          }

          postgres_job_spec['networks'] << {
              'name' => 'b'
          }

          upload_cloud_config(cloud_config_hash: cloud_config)
          deploy_simple_manifest(manifest_hash: manifest)
          should_contain_network_for_job('my_api', 'api_server', /.b./)
        end

        it 'raise an error if network name specified is not one of the networks on the link' do
          manifest['jobs'].first['templates'].first['consumes'] = {
              'db' => {'from' => 'simple.db', 'network' => 'invalid_network'},
              'backup_db' => {'from' => 'simple.backup_db', 'network' => 'a'}
          }

          expect{deploy_simple_manifest(manifest_hash: manifest)}.to raise_error(RuntimeError, /Error 130002: Network name 'invalid_network' is not one of the networks on the link 'db'/)
        end
      end

      context 'when user does not specify a network in consumes' do

        let(:links) do
          {
              'db' => {'from' => 'simple.db'},
              'backup_db' => {'from' => 'simple.backup_db'}
          }
        end

        it 'uses the network from link when only one network is available' do

          mysql_job_spec = Bosh::Spec::Deployments.simple_job(
              name: 'mysql',
              templates: [{'name' => 'database'}],
              instances: 1,
              static_ips: ['192.168.1.10']
          )
          mysql_job_spec['azs'] = ['z1']

          manifest['jobs'] = [api_job_spec, mysql_job_spec, postgres_job_spec]

          deploy_simple_manifest(manifest_hash: manifest)
          should_contain_network_for_job('my_api', 'api_server', /192.168.1.1(0|2)/)
        end

        it 'uses the default network when multiple networks are available from link' do
          postgres_job_spec['networks'] << {
              'name' => 'dynamic-network',
              'default' => ['dns', 'gateway']
          }
          deploy_simple_manifest(manifest_hash: manifest)
          should_contain_network_for_job('my_api', 'api_server', /.dynamic-network./)
        end

      end
    end
  end
end
