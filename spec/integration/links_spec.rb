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

    context 'when provided and required links have different names but same type' do

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
