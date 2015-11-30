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

  before do
    target_and_login
    upload_links_release
    upload_stemcell
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

    upload_cloud_config(cloud_config_hash: cloud_config_hash)
  end

  context 'when job requires link' do
    let(:api_job_spec) do
      job_spec = Bosh::Spec::Deployments.simple_job(
        name: 'my_api',
        templates: [{'name' => 'api_server', 'links' => links}],
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
        templates: [{'name' => 'database'}],
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
          'db' => 'simple.mysql.database.db',
          'backup_db' => 'simple.postgres.database.backup_db'
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
                  'name' => 'a',
                  'address' => '192.168.1.10',
                },
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
                  'name' => 'a',
                  'address' => '192.168.1.11',
                },
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
          'db' => 'simple.mysql.database.db',
          'backup_db' => 'simple.mongo.mongo_db.read_only_db',
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
          templates: [{'name' => 'node', 'links' => first_node_links}],
          instances: 1,
          static_ips: ['192.168.1.10']
        )
        job_spec['azs'] = ['z1']
        job_spec
      end

      let(:first_node_links) do
        {
          'node1' => 'simple.second_node.node.node1',
          'node2' => 'simple.first_node.node.node2'
        }
      end

      let(:second_node_job_spec) do
        job_spec = Bosh::Spec::Deployments.simple_job(
          name: 'second_node',
          templates: [{'name' => 'node', 'links' => second_node_links}],
          instances: 1,
          static_ips: ['192.168.1.11']
        )
        job_spec['azs'] = ['z1']
        job_spec
      end
      let(:second_node_links) do
        {
          'node1' => 'simple.first_node.node.node1',
          'node2' => 'simple.first_node.node.node2'
        }
      end

      let(:manifest) do
        manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
        manifest['jobs'] = [first_node_job_spec, second_node_job_spec]
        manifest
      end

      it 'renders link data in job template' do
        deploy_simple_manifest(manifest_hash: manifest)

        first_node_vm = director.vm('first_node', '0')
        first_node_template = YAML.load(first_node_vm.read_job_template('node', 'config.yml'))

        expect(first_node_template['nodes']['node1_ips']).to eq(['192.168.1.11'])
        expect(first_node_template['nodes']['node2_ips']).to eq(['192.168.1.10'])

        second_node_vm = director.vm('second_node', '0')
        second_node_template = YAML.load(second_node_vm.read_job_template('node', 'config.yml'))

        expect(second_node_template['nodes']['node1_ips']).to eq(['192.168.1.10'])
        expect(second_node_template['nodes']['node2_ips']).to eq(['192.168.1.10'])
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
          templates: [{'name' => 'node', 'links' => first_node_links}],
          instances: 1,
          static_ips: ['192.168.1.10']
        )
      end

      let(:first_node_links) do
        {
          'node1' => 'simple.second_node.node.node1',
          'node2' => 'simple.first_node.node.node2'
        }
      end

      let(:second_node_job_spec) do
        Bosh::Spec::Deployments.simple_job(
          name: 'second_node',
          templates: [{'name' => 'node', 'links' => second_node_links}],
          instances: 1,
          static_ips: ['192.168.1.11']
        )
      end
      let(:second_node_links) do
        {
          'node1' => 'broken.link.is.broken',
          'node2' => 'other.broken.link.blah'
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
          templates: [{'name' => 'node', 'links' => first_deployment_links}],
          instances: 1,
          static_ips: ['192.168.1.10']
        )
        job_spec['azs'] = ['z1']
        job_spec
      end

      let(:first_deployment_links) do
        {
          'node1' => 'first.first_deployment_node.node.node1',
          'node2' => 'first.first_deployment_node.node.node2'
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
          templates: [{'name' => 'node', 'links' => second_deployment_links}],
          instances: 1,
          static_ips: ['192.168.1.11']
        )
        job_spec['azs'] = ['z1']
        job_spec
      end

      let(:second_deployment_links) do
        {
          'node1' => 'first.first_deployment_node.node.node1',
          'node2' => 'second.second_deployment_node.node.node2'
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
  end
end
