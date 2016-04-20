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
      database.each do |instance|
          expect(instance['address']).to match(pattern)
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

    let(:links) {{}}

    context 'properties with aliased links' do
      let(:db3_job) do
        job_spec = Bosh::Spec::Deployments.simple_job(
            name: 'db3',
            templates: [
                {'name' => 'http_server_with_provides', 'provides' => {'http_endpoint' => {'as' => 'http_endpoint2', 'shared' => true}}},
                {'name' => 'kv_http_server'}
            ],
            instances: 1
        )
        job_spec['azs'] = ['z1']
        job_spec['properties'] = {'listen_port' => 8082, 'kv_http_server' => {'listen_port' => 8081}, "name_space" => {"prop_a" => "job_value", "fibonacci" => 1}}
        job_spec
      end

      let(:other2_job) do
        job_spec = Bosh::Spec::Deployments.simple_job(
            name: 'other2',
            templates: [
                {'name' => 'http_proxy_with_requires', 'properties' => {'http_proxy_with_requires.listen_port' => 21}, 'consumes' => {'proxied_http_endpoint' => {'from' => 'http_endpoint2', 'shared' => true}, 'logs_http_endpoint' => nil}},
                {'name' => 'http_server_with_provides', 'properties' => {'listen_port' => 8446}}
            ],
            instances: 1
        )
        job_spec['azs'] = ['z1']
        job_spec
      end

      let(:new_job) do
        job_spec = Bosh::Spec::Deployments.simple_job(
            name: 'new_job',
            templates: [
                {'name' => 'http_proxy_with_requires', 'consumes' => {'proxied_http_endpoint' => {'from' => 'new_provides', 'shared' => true}, 'logs_http_endpoint' => nil}},
                {'name' => 'http_server_with_provides', 'provides'=>{'http_endpoint' => {'as' =>'new_provides'}}}
            ],
            instances: 1
        )
        job_spec['azs'] = ['z1']
        job_spec
      end

      let(:manifest) do
        manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
        manifest['jobs'] = [db3_job, other2_job, new_job]
        manifest['properties'] = {'listen_port' => 9999}
        manifest
      end

      it 'is able to pick the right value for the property from global, job, template and default values' do
        deploy_simple_manifest(manifest_hash: manifest)
        vms = director.vms
        link_vm = find_vm(vms, 'other2', '0')
        template = YAML.load(link_vm.read_job_template('http_proxy_with_requires', 'config/config.yml'))
        expect(template['links']).to contain_exactly(["address", "192.168.1.2"], ["properties", {"listen_port"=>8082, "name_space"=>{"prop_a"=>"job_value"}, "fibonacci"=>1}])

        link_vm = find_vm(vms, 'new_job', '0')
        template = YAML.load(link_vm.read_job_template('http_proxy_with_requires', 'config/config.yml'))
        expect(template['links']).to contain_exactly(["address", "192.168.1.4"], ["properties", {"listen_port"=>9999, "name_space"=>{"prop_a"=>"default"}}])
      end
    end

    context 'when link is provided' do
      let(:links) do
        {
          'db' => {'from' => 'db'},
          'backup_db' => {'from' => 'backup_db'}
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
              'id' => "#{mysql_0_vm.instance_uuid}",
              'name' => 'mysql',
              'index' => 0,
              'address' => "#{mysql_0_vm.instance_uuid}.mysql.dynamic-network.simple.bosh"
            },
            {
              'id' => "#{mysql_1_vm.instance_uuid}",
              'name' => 'mysql',
              'index' => 1,
              'address' => "#{mysql_1_vm.instance_uuid}.mysql.dynamic-network.simple.bosh"
            }
          )

        expect(template['databases']['backup']).to contain_exactly(
            {
              'name' => 'postgres',
              'az' => 'z1',
              'index' => 0,
              'address' => '192.168.1.12'
            }
          )
      end
    end

    context 'when dealing with optional links' do

      let(:api_job_with_optional_links_spec_1) do
        job_spec = Bosh::Spec::Deployments.simple_job(
            name: 'my_api',
            templates: [{'name' => 'api_server_with_optional_links_1', 'consumes' => links}],
            instances: 1
        )
        job_spec['azs'] = ['z1']
        job_spec
      end

      let(:api_job_with_optional_links_spec_2) do
        job_spec = Bosh::Spec::Deployments.simple_job(
            name: 'my_api',
            templates: [{'name' => 'api_server_with_optional_links_2', 'consumes' => links}],
            instances: 1
        )
        job_spec['azs'] = ['z1']
        job_spec
      end

      let(:manifest) do
        manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
        manifest['jobs'] = [api_job_with_optional_links_spec_1, mysql_job_spec, postgres_job_spec]
        manifest
      end

      context 'when optional links are explicitly stated in deployment manifest' do
        let(:links) do
          {
              'db' => {'from' => 'db'},
              'backup_db' => {'from' => 'backup_db'},
              'optional_link_name' => {'from' => 'backup_db'}
          }
        end

        it 'throws an error if the optional link was not found' do
          out, exit_code = deploy_simple_manifest(manifest_hash: manifest, failure_expected: true, return_exit_code: true)
          expect(exit_code).not_to eq(0)
          expect(out).to include("Error 190016: Cannot resolve link path 'simple.postgres.backup_database.backup_db' required for link 'optional_link_name' in instance group 'my_api' on job 'api_server_with_optional_links_1'")
        end
      end

      context 'when optional links are not explicitly stated in deployment manifest' do
        let(:links) do
          {
              'db' => {'from' => 'db'},
              'backup_db' => {'from' => 'backup_db'}
          }
        end

        it 'should not throw an error if the optional link was not found' do
          out, exit_code = deploy_simple_manifest(manifest_hash: manifest, return_exit_code: true)
          expect(exit_code).to eq(0)
          expect(out).to include("Deployed 'simple' to 'Test Director'")
        end
      end

      context 'when a job spec specifies an optional key in a provides link' do
        it 'should fail when uploading the release' do
          expect {
            bosh_runner.run("upload release #{spec_asset('links_releases/corrupted_release_optional_provides-0+dev.1.tgz')}")
          }.to raise_error(RuntimeError, /Error 80013: Link 'node1' of type 'node1' is a provides link, not allowed to have 'optional' key/)
        end
      end

      context 'when a consumed link is set to nil in the deployment manifest' do
        context 'when the link is optional and it does not exist' do
          let(:links) do
            {
                'db' => {'from' => 'db'},
                'backup_db' => {'from' => 'backup_db'},
                'optional_link_name' => 'nil'
            }
          end

          it 'should not render link data in job template' do
            deploy_simple_manifest(manifest_hash: manifest)

            link_vm = director.vm('my_api', '0')
            template = YAML.load(link_vm.read_job_template('api_server_with_optional_links_1', 'config.yml'))

            expect(template['optional_key']).to eq(nil)
          end
        end

        context 'when the link is optional and it exists' do
          let(:links) do
            {
                'db' => {'from' => 'db'},
                'backup_db' => 'nil',
            }
          end

          let(:manifest) do
            manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
            manifest['jobs'] = [api_job_with_optional_links_spec_2, mysql_job_spec, postgres_job_spec]
            manifest
          end

          it 'should not render link data in job template' do
            deploy_simple_manifest(manifest_hash: manifest)

            link_vm = director.vm('my_api', '0')
            template = YAML.load(link_vm.read_job_template('api_server_with_optional_links_2', 'config.yml'))

            expect(template['databases']['backup']).to eq(nil)
          end
        end

        context 'when the link is not optional' do
          let(:links) do
            {
                'db' => 'nil',
                'backup_db' => {'from' => 'backup_db'}
            }
          end

          it 'should throw an error' do
            out, exit_code = deploy_simple_manifest(manifest_hash: manifest, failure_expected: true, return_exit_code: true)
            expect(exit_code).not_to eq(0)
            expect(out).to include("Error 140014: Link path was not provided for required link 'db' in instance group 'my_api'")
          end
        end
      end

      context 'when if_link and else_if_link are used in job templates' do

        let(:links) do
          {
              'db' => {'from' => 'db'},
              'backup_db' => {'from' => 'backup_db'},
          }
        end

        let(:manifest) do
          manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
          manifest['jobs'] = [api_job_with_optional_links_spec_2, mysql_job_spec, postgres_job_spec]
          manifest
        end

        it 'should respect their behavior' do
          deploy_simple_manifest(manifest_hash: manifest)

          link_vm = director.vm('my_api', '0')
          template = YAML.load(link_vm.read_job_template('api_server_with_optional_links_2', 'config.yml'))

          expect(template['databases']['backup2'][0]['name']).to eq('postgres')
          expect(template['databases']['backup2'][0]['az']).to eq('z1')
          expect(template['databases']['backup2'][0]['index']).to eq(0)
          expect(template['databases']['backup2'][0]['address']).to eq('192.168.1.12')
          expect(template['databases']['backup3']).to eq('happy')
        end
      end

      context 'when the optional link is used without if_link in templates' do
        let(:api_job_with_bad_optional_links) do
          job_spec = Bosh::Spec::Deployments.simple_job(
              name: 'my_api',
              templates: [{'name' => 'api_server_with_bad_optional_links'}],
              instances: 1
          )
          job_spec['azs'] = ['z1']
          job_spec
        end

        let(:manifest) do
          manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
          manifest['jobs'] = [api_job_with_bad_optional_links]
          manifest
        end

        it 'should throw a legitimate error if link was not found' do
          out, exit_code = deploy_simple_manifest(manifest_hash: manifest, failure_expected: true, return_exit_code: true)
          expect(out).to include <<-EOF
Error 100: Unable to render instance groups for deployment. Errors are:
   - Unable to render jobs for instance group 'my_api'. Errors are:
     - Unable to render templates for job 'api_server_with_bad_optional_links'. Errors are:
       - Error filling in template 'config.yml.erb' (line 3: Can't find link 'optional_link_name')
          EOF
        end
      end

      context 'when multiple links with same type being provided' do
        let(:api_server_with_optional_db_links)do
          job_spec = Bosh::Spec::Deployments.simple_job(
              name: 'optional_db',
              templates: [{'name' => 'api_server_with_optional_db_link'}],
              instances: 1,
              static_ips: ['192.168.1.13']
          )
          job_spec['azs'] = ['z1']
          job_spec
        end

        let(:manifest) do
          manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
          manifest['jobs'] = [api_server_with_optional_db_links, mysql_job_spec, postgres_job_spec]
          manifest
        end

        it 'fails when the consumed optional link `from` key is not explicitly set in the deployment manifest' do
          output, exit_code = deploy_simple_manifest(manifest_hash: manifest, failure_expected: true, return_exit_code: true)

          expect(exit_code).not_to eq(0)
          expect(output).to include <<-EOF
Error 100: Unable to process links for deployment. Errors are:
   - "Multiple instance groups provide links of type 'db'. Cannot decide which one to use for instance group 'optional_db'.
     simple.mysql.database.db
     simple.postgres.backup_database.backup_db"
          EOF
        end
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

      it 'should successfully compile a release without complaining about missing links' do
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
        expect(out).to include('Started copying jobs > addon/39adedad4737bc2acce16352c55c14de0a601512. Done')
        expect(out).to include('Started copying jobs > api_server/8c6864dd746cadc5c39259b0b7a1fe9f40205b65. Done')
        expect(out).to include('Started copying jobs > api_server_with_bad_link_types/5efc0322b51eace0b355e7613f06b7238d2a04c7. Done')
        expect(out).to include('Started copying jobs > api_server_with_bad_optional_links/1df8cd1987c1711bb04af2f43378715296070765. Done')
        expect(out).to include('Started copying jobs > api_server_with_optional_db_link/0546154e8a50dd973e8480e69638645583cb38d9. Done')
        expect(out).to include('Started copying jobs > api_server_with_optional_links_1/5ae8a1435d098577de613fe4de18c252b1a624d3. Done')
        expect(out).to include('Started copying jobs > api_server_with_optional_links_2/a4c1f8bc664578874ea9de1dc0618b9f3e811172. Done')
        expect(out).to include('Started copying jobs > backup_database/c6802f3d21e6c2367520629c691ab07e0e49be6d. Done')
        expect(out).to include('Started copying jobs > database/6f16ca3fad0d120eefd91334f4c8d3584886cc3d. Done')
        expect(out).to include('Started copying jobs > mongo_db/2a32a7517a77bfa606a7a4ae0ae8097bf36505df. Done')
        expect(out).to include('Started copying jobs > node/6cd263ed6b6cef423ab50664805c0f6d9987779f. Done')
        expect(out).to include('Done copying jobs')

        expect(out).to include("Exported release 'bosh-release/0+dev.1' for 'toronto-os/1'")
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
          'db' => {'from'=>'db'},
          'backup_db' => {'from' => 'read_only_db'},
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
              'address' => '192.168.1.13'
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
          'node1' => {'from' => 'node1'},
          'node2' => {'from' => 'node2'}
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
          'node1' => {'from' => 'node1'},
          'node2' => {'from' => 'node2'}
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

        postgres_vm = director.vm('postgres', '0')

        expect(template['databases']['main'].size).to eq(1)
        expect(template['databases']['main']).to contain_exactly(
             {
                 'id' => "#{postgres_vm.instance_uuid}",
                 'name' => 'postgres',
                 'index' => 0,
                 'address' => '192.168.1.12'
             }
         )

        expect(template['databases']['backup'].size).to eq(1)
        expect(template['databases']['backup']).to contain_exactly(
             {
                 'name' => 'postgres',
                 'index' => 0,
                 'az' => 'z1',
                 'address' => '192.168.1.12'
             }
         )
      end
    end

    context 'when provide and consume links are set in spec, and implied by deployment manifest, but there are multiple provide links with same type' do

      context 'when both provided links are on separate templates' do
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

      context 'when both provided links are in same template' do
        let(:job_with_same_type_links) do
          job_spec = Bosh::Spec::Deployments.simple_job(
              name: 'duplicate_link_type_job',
              templates: [{'name' => 'database_with_two_provided_link_of_same_type'}],
              instances: 1
          )
          job_spec['azs'] = ['z1']
          job_spec
        end

        let(:manifest) do
          manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
          manifest['jobs'] = [implied_job_spec, job_with_same_type_links]
          manifest
        end

        it 'raises error' do
          _, exit_code = deploy_simple_manifest(manifest_hash: manifest, failure_expected: true, return_exit_code: true)
          expect(exit_code).not_to eq(0)
          expect(director.vms('simple')).to eq([])
        end

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
            'backup_db' => {'from' => 'link_alias'},
        }
      end

      it 'renders link data in job template' do
        deploy_simple_manifest(manifest_hash: manifest)

        link_vm = director.vm('my_api', '0')
        aliased_postgres_vm = director.vm('aliased_postgres', '0')

        template = YAML.load(link_vm.read_job_template('api_server', 'config.yml'))

        expect(template['databases']['main'].size).to eq(1)
        expect(template['databases']['main']).to contain_exactly(
           {
               'id' => "#{aliased_postgres_vm.instance_uuid}",
               'name' => 'aliased_postgres',
               'index' => 0,
               'address' => '192.168.1.3'
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
            'backup_db' => {'from' => 'backup_db'},
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
            'backup_db' => {'from' => 'link_alias'},
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

        new_aliased_job_vm = director.vm('new_aliased_job', '0')

        expect(template['databases']['main'].size).to eq(1)
        expect(template['databases']['main']).to contain_exactly(
           {
               'id' => "#{new_aliased_job_vm.instance_uuid}",
               'name' => 'new_aliased_job',
               'index' => 0,
               'address' => '192.168.1.5'
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
          templates: [{'name' => 'node', 'consumes' => first_node_links,'provides' => {'node2' => {'as' => 'alias2'}}}],
          instances: 1,
          static_ips: ['192.168.1.10'],
          azs: ["z1"]
        )
      end

      let(:first_node_links) do
        {
          'node1' => {'from' => 'node1'},
          'node2' => {'from' => 'alias2'}
        }
      end

      let(:second_node_job_spec) do
        Bosh::Spec::Deployments.simple_job(
          name: 'second_node',
          templates: [{'name' => 'node', 'consumes' => second_node_links, 'provides' => {'node2' => {'as' => 'alias2'}}}],
          instances: 1,
          static_ips: ['192.168.1.11'],
          azs: ["z1"]
        )
      end

      let(:second_node_links) do
        {
          'node1' => {'from' => 'broken', 'deployment' => 'broken'},
          'node2' => {'from' =>'blah', 'deployment' => 'other'}
        }
      end

      it 'catches broken link before updating vms' do
        output, exit_code = deploy_simple_manifest(manifest_hash: manifest, failure_expected: true, return_exit_code: true)
        expect(exit_code).not_to eq(0)
        expect(director.vms('simple')).to eq([])
        expect(output).to include("Cannot resolve ambiguous link 'node1' (job: node, instance group: first_node). All of these match:")
        expect(output).to include("Cannot resolve ambiguous link 'alias2' (job: node, instance group: first_node). All of these match:")
        expect(output).to include("Can't find deployment broken")
        expect(output).to include("Can't find deployment other")
      end
  end

    context 'when link references another deployment' do

     let(:first_manifest) do
       manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
       manifest['name'] = 'first'
       manifest['jobs'] = [first_deployment_job_spec]
       manifest
     end

     let(:first_deployment_job_spec) do
       job_spec = Bosh::Spec::Deployments.simple_job(
           name: 'first_deployment_node',
           templates: [{'name' => 'node', 'consumes' => first_deployment_consumed_links, 'provides' => first_deployment_provided_links}],
           instances: 1,
           static_ips: ['192.168.1.10'],
       )
       job_spec['azs'] = ['z1']
       job_spec
     end

     let(:first_deployment_consumed_links) do
       {
           'node1' => {'from' => 'node1', 'deployment' => 'first'},
           'node2' => {'from' => 'node2', 'deployment' => 'first'}
       }
     end

     let(:first_deployment_provided_links) do
       { 'node1' => {'shared' => true},
         'node2' => {'shared' => true}}
     end

     let(:second_deployment_job_spec) do
       job_spec = Bosh::Spec::Deployments.simple_job(
           name: 'second_deployment_node',
           templates: [{'name' => 'node', 'consumes' => second_deployment_consumed_links}],
           instances: 1,
           static_ips: ['192.168.1.11']
       )
       job_spec['azs'] = ['z1']
       job_spec
     end

     let(:second_manifest) do
       manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
       manifest['name'] = 'second'
       manifest['jobs'] = [second_deployment_job_spec]
       manifest
     end

     let(:second_deployment_consumed_links) do
       {
           'node1' => {'from' => 'node1', 'deployment' => 'first'},
           'node2' => {'from' => 'node2', 'deployment' => 'second'}
       }
     end

     context 'when consumed link is shared across deployments' do
       it 'should successfully use the shared link' do
         deploy_simple_manifest(manifest_hash: first_manifest)

         expect {
           deploy_simple_manifest(manifest_hash: second_manifest)
         }.to_not raise_error
       end

       it 'allows access to bootstrap node' do
         deploy_simple_manifest(manifest_hash: first_manifest)

         first_deployment_vm = director.vm('first_deployment_node', '0', deployment: 'first')
         first_deployment_template = YAML.load(first_deployment_vm.read_job_template('node', 'config.yml'))

         second_manifest['jobs'][0]['instances'] = 2
         second_manifest['jobs'][0]['static_ips'] = ['192.168.1.12', '192.168.1.13']
         second_manifest['jobs'][0]['networks'][0]['static_ips'] = ['192.168.1.12', '192.168.1.13']

         deploy_simple_manifest(manifest_hash: second_manifest)

         second_deployment_vm = director.vm('second_deployment_node', '0', deployment: 'second')
         second_deployment_template = YAML.load(second_deployment_vm.read_job_template('node', 'config.yml'))
         expect(second_deployment_template['instances']['node1_bootstrap_address']).to eq(first_deployment_template['instances']['node1_bootstrap_address'])
       end

       context 'when user does not specify a network for consumes' do
         it 'should use default network' do
           deploy_simple_manifest(manifest_hash: first_manifest)
           deploy_simple_manifest(manifest_hash: second_manifest)

           second_deployment_vm = director.vm('second_deployment_node', '0', deployment: 'second')
           second_deployment_template = YAML.load(second_deployment_vm.read_job_template('node', 'config.yml'))

           expect(second_deployment_template['instances']['node1_ips']).to eq(['192.168.1.10'])
           expect(second_deployment_template['instances']['node2_ips']).to eq(['192.168.1.11'])
         end
       end

       context 'when user specifies a valid network for consumes' do

         let(:second_deployment_consumed_links) do
           {
               'node1' => {'from' => 'node1', 'deployment'=>'first', 'network' => 'test'},
               'node2' => {'from' => 'node2', 'deployment'=>'second'}
           }
         end

         before do
           cloud_config['networks'] << {
               'name' => 'test',
               'type' => 'dynamic',
               'subnets' => [{'az' => 'z1'}]
           }

           first_deployment_job_spec['networks'] << {
               'name' => 'test'
           }

           first_deployment_job_spec['networks'] << {
               'name' => 'dynamic-network',
               'default' => ['dns', 'gateway']
           }

           upload_cloud_config(cloud_config_hash: cloud_config)
         end

         it 'should use user specified network from provider job' do
           deploy_simple_manifest(manifest_hash: first_manifest)
           deploy_simple_manifest(manifest_hash: second_manifest)

           second_deployment_vm = director.vm('second_deployment_node', '0', deployment: 'second')
           second_deployment_template = YAML.load(second_deployment_vm.read_job_template('node', 'config.yml'))

           expect(second_deployment_template['instances']['node1_ips'].first).to match(/.test./)
           expect(second_deployment_template['instances']['node2_ips'].first).to eq('192.168.1.11')
         end
       end

       context 'when user specifies an invalid network for consumes' do

         let(:second_deployment_consumed_links) do
           {
               'node1' => {'from' => 'node1', 'deployment'=>'first', 'network' => 'invalid-network'},
               'node2' => {'from' => 'node2', 'deployment'=>'second'}
           }
         end

         it 'raises an error' do
           deploy_simple_manifest(manifest_hash: first_manifest)

           expect {
             deploy_simple_manifest(manifest_hash: second_manifest)
           }.to raise_error(RuntimeError, /Can't resolve link 'node1' in instance group 'second_deployment_node' on job 'node' in deployment 'second' and network 'invalid-network''. Please make sure the link was provided and shared\./)
         end

         context 'when provider job has 0 instances' do
           let(:first_deployment_job_spec) do
             job_spec = Bosh::Spec::Deployments.simple_job(
                 name: 'first_deployment_node',
                 templates: [{'name' => 'node', 'consumes' => first_deployment_consumed_links, 'provides' => first_deployment_provided_links}],
                 instances: 0,
                 static_ips: [],
             )
             job_spec['azs'] = ['z1']
             job_spec
           end

           it 'raises the error' do
             deploy_simple_manifest(manifest_hash: first_manifest)

             expect {
               deploy_simple_manifest(manifest_hash: second_manifest)
             }.to raise_error(RuntimeError, /Can't resolve link 'node1' in instance group 'second_deployment_node' on job 'node' in deployment 'second' and network 'invalid-network''. Please make sure the link was provided and shared\./)
           end
         end
       end
     end

     context 'when consumed link is not shared across deployments' do

       let(:first_deployment_provided_links) do
         { 'node1' => {'shared' => false} }
       end

       it 'should raise an error' do
         deploy_simple_manifest(manifest_hash: first_manifest)

         expect {
           deploy_simple_manifest(manifest_hash: second_manifest)
         }.to raise_error(RuntimeError, /Can't resolve link 'node1' in instance group 'second_deployment_node' on job 'node' in deployment 'second'. Please make sure the link was provided and shared\./)
       end
     end

   end

    describe 'network resolution' do

      context 'when user specifies a network in consumes' do

        let(:links) do
          {
              'db' => {'from' => 'db', 'network' => 'b'},
              'backup_db' => {'from' => 'backup_db', 'network' => 'b'}
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

        it 'raises an error if network name specified is not one of the networks on the link' do
          manifest['jobs'].first['templates'].first['consumes'] = {
              'db' => {'from' => 'db', 'network' => 'invalid_network'},
              'backup_db' => {'from' => 'backup_db', 'network' => 'a'}
          }

          expect{deploy_simple_manifest(manifest_hash: manifest)}.to raise_error(RuntimeError, /Can't resolve link 'db' in instance group 'my_api' on job 'api_server' in deployment 'simple' and network 'invalid_network'./)
        end

        it 'raises an error if network name specified is not one of the networks on the link and is a global network' do
          cloud_config['networks'] << {
              'name' => 'global_network',
              'type' => 'dynamic',
              'subnets' => [{'az' => 'z1'}]
          }

          manifest['jobs'].first['templates'].first['consumes'] = {
              'db' => {'from' => 'db', 'network' => 'global_network'},
              'backup_db' => {'from' => 'backup_db', 'network' => 'a'}
          }

          upload_cloud_config(cloud_config_hash: cloud_config)
          expect{deploy_simple_manifest(manifest_hash: manifest)}.to raise_error(RuntimeError, /Can't resolve link 'db' in instance group 'my_api' on job 'api_server' in deployment 'simple' and network 'global_network'./)
        end

        context 'user has duplicate implicit links provided in two jobs over seprate networks' do

          let(:mysql_job_spec) do
            job_spec = Bosh::Spec::Deployments.simple_job(
                name: 'mysql',
                templates: [{'name' => 'database'}],
                instances: 2,
                static_ips: ['192.168.1.10', '192.168.1.11']
            )
            job_spec['azs'] = ['z1']
            job_spec['networks'] = [{
                'name' => 'dynamic-network',
                'default' => ['dns', 'gateway']
            }]
            job_spec
          end

          let(:links) do
            {
                'db' => {'network' => 'dynamic-network'},
                'backup_db' => {'network' => 'a'}
            }
          end

          it "should choose link from correct network" do
            upload_cloud_config(cloud_config_hash: cloud_config)
            deploy_simple_manifest(manifest_hash: manifest)
          end
        end

      end

      context 'when user does not specify a network in consumes' do

        let(:links) do
          {
              'db' => {'from' => 'db'},
              'backup_db' => {'from' => 'backup_db'}
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

    context 'when link provider specifies properties from job spec' do
      let(:mysql_job_spec) do
        job_spec = Bosh::Spec::Deployments.simple_job(
            name: 'mysql',
            templates: [{'name' => 'database', 'properties' => {'test' => 'test value' }}],
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

      let(:manifest) do
        manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
        manifest['jobs'] = [mysql_job_spec]
        manifest
      end

      it 'allows to be deployed' do
        expect{ deploy_simple_manifest(manifest_hash: manifest) }.to_not raise_error
      end
    end

    context 'when link provider specifies properties not listed in job spec properties' do
      let(:mysql_job_spec) do
        job_spec = Bosh::Spec::Deployments.simple_job(
            name: 'mysql',
            templates: [{'name' => 'provider_fail'}],
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

      it 'fails if the property specified for links is not provided by job template' do
        expect{ deploy_simple_manifest(manifest_hash: manifest) }.to raise_error(RuntimeError, /Link property b in template provider_fail is not defined in release spec/)
      end
    end

    context 'when multiple versions of a release are uploaded' do
      let(:links) do
        {
            'db' => {'from' => 'db'},
            'backup_db' => {'from' => 'backup_db'}
        }
      end

      let(:job_consumes_link_spec) do
        job_spec = Bosh::Spec::Deployments.simple_job(
            name: 'deployment-job',
            templates: [{'name' => 'api_server', 'consumes' => links}],
            instances: 1
        )
        job_spec['azs'] = ['z1']
        job_spec
      end

      let(:job_not_consuming_links_spec) do
        job_spec = Bosh::Spec::Deployments.simple_job(
            name: 'deployment-job',
            templates: [{'name' => 'api_server'}],
            instances: 1
        )
        job_spec['azs'] = ['z1']
        job_spec
      end

      it 'should only look at the specific release version templates when getting links' do
        # ####################################################################
        # 1- Deploy release version dev.1 that has jobs with links
        bosh_runner.run("upload release #{spec_asset('links_releases/release_with_minimal_links-0+dev.1.tgz')}")
        manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
        manifest['releases'].clear
        manifest['releases'] << {
            'name' => 'release_with_minimal_links',
            'version' => '0+dev.1'
        }
        manifest['jobs'] = [job_consumes_link_spec, mysql_job_spec, postgres_job_spec]

        output_1, exit_code_1 = deploy_simple_manifest(manifest_hash: manifest, return_exit_code: true)
        expect(exit_code_1).to eq(0)
        expect(output_1).to include("Started creating missing vms > deployment-job/0")
        expect(output_1).to include("Started creating missing vms > mysql/0")
        expect(output_1).to include("Started creating missing vms > mysql/1")
        expect(output_1).to include("Started creating missing vms > postgres/0")

        expect(output_1).to include("Started updating job deployment-job > deployment-job/0")
        expect(output_1).to include("Started updating job mysql > mysql/0")
        expect(output_1).to include("Started updating job mysql > mysql/1")
        expect(output_1).to include("Started updating job postgres > postgres/0")


        # ####################################################################
        # 2- Deploy release version dev.2 where its jobs were updated to not have links
        bosh_runner.run("upload release #{spec_asset('links_releases/release_with_minimal_links-0+dev.2.tgz')}")

        manifest['releases'].clear
        manifest['releases'] << {
            'name' => 'release_with_minimal_links',
            'version' => 'latest'
        }
        manifest['jobs'].clear
        manifest['jobs'] = [job_not_consuming_links_spec, mysql_job_spec, postgres_job_spec]

        output_2, exit_code_2 = deploy_simple_manifest(manifest_hash: manifest, return_exit_code: true)
        expect(exit_code_2).to eq(0)
        expect(output_2).to_not include("Started creating missing vms > deployment-job/0")
        expect(output_2).to_not include("Started creating missing vms > mysql/0")
        expect(output_2).to_not include("Started creating missing vms > mysql/1")
        expect(output_2).to_not include("Started creating missing vms > postgres/0")

        expect(output_2).to include("Started updating job deployment-job > deployment-job/0")
        expect(output_2).to include("Started updating job mysql > mysql/0")
        expect(output_2).to include("Started updating job mysql > mysql/1")
        expect(output_2).to include("Started updating job postgres > postgres/0")

        current_deployments = bosh_runner.run("deployments")
        expect(current_deployments).to match_output %(
          +--------+------------------------------------+-------------------+--------------+
          | Name   | Release(s)                         | Stemcell(s)       | Cloud Config |
          +--------+------------------------------------+-------------------+--------------+
          | simple | release_with_minimal_links/0+dev.2 | ubuntu-stemcell/1 | latest       |
          +--------+------------------------------------+-------------------+--------------+
        )


        # ####################################################################
        # 3- Re-deploy release version dev.1 that has jobs with links. It should still work
        manifest['releases'].clear
        manifest['releases'] << {
            'name' => 'release_with_minimal_links',
            'version' => '0+dev.1'
        }
        manifest['jobs'] = [job_consumes_link_spec, mysql_job_spec, postgres_job_spec]

        output_3, exit_code_3 = deploy_simple_manifest(manifest_hash: manifest, return_exit_code: true)
        expect(exit_code_3).to eq(0)
        expect(output_3).to_not include("Started creating missing vms > deployment-job/0")
        expect(output_3).to_not include("Started creating missing vms > mysql/0")
        expect(output_3).to_not include("Started creating missing vms > mysql/1")
        expect(output_3).to_not include("Started creating missing vms > postgres/0")

        expect(output_3).to include("Started updating job deployment-job > deployment-job/0")
        expect(output_3).to include("Started updating job mysql > mysql/0")
        expect(output_3).to include("Started updating job mysql > mysql/1")
        expect(output_3).to include("Started updating job postgres > postgres/0")
      end

      it 'allows only the specified properties' do
        expect{ deploy_simple_manifest(manifest_hash: manifest) }.to_not raise_error
      end
    end
  end

  context 'when addon job requires link' do

    let(:mysql_job_spec) do
      job_spec = Bosh::Spec::Deployments.simple_job(
          name: 'mysql',
          templates: [{'name' => 'database'}],
          instances: 1,
          static_ips: ['192.168.1.10']
      )
      job_spec['azs'] = ['z1']
      job_spec['networks'] << {
          'name' => 'dynamic-network',
          'default' => ['dns', 'gateway']
      }
      job_spec
    end

    before do
      Dir.mktmpdir do |tmpdir|
        runtime_config_filename = File.join(tmpdir, 'runtime_config.yml')
        File.write(runtime_config_filename, Psych.dump(Bosh::Spec::Deployments.runtime_config_with_links))
        bosh_runner.run("update runtime-config #{runtime_config_filename}")
      end
    end

    it 'should resolve links for addons' do
      manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
      manifest['releases'][0]['version'] = '0+dev.1'
      manifest['jobs'] = [mysql_job_spec]

      deploy_simple_manifest(manifest_hash: manifest)

      my_sql_vm = director.vm("mysql", '0', deployment: 'simple')
      template = YAML.load(my_sql_vm.read_job_template("addon", 'config.yml'))

      template['databases'].each do |_, database|
        database.each do |instance|
          expect(instance['address']).to match(/.dynamic-network./)
        end
      end
    end
  end

  context 'checking link properties' do
    let(:job_with_nil_properties) do
      job_spec = Bosh::Spec::Deployments.simple_job(
          name: 'property_job',
          templates: [{'name' => 'provider', 'properties' => {'a' => 'deployment_a'}}, {'name' => 'consumer'}],
          instances: 1,
          static_ips: ['192.168.1.10'],
          properties: {}
      )
      job_spec['azs'] = ['z1']
      job_spec['networks'] << {
          'name' => 'dynamic-network',
          'default' => ['dns', 'gateway']
      }
      job_spec
    end

    let (:job_with_manual_consumes_link) do
      job_spec = Bosh::Spec::Deployments.simple_job(
          name: 'property_job',
          templates: [{'name' => 'consumer', 'consumes' => {'provider' => {'properties' => {'a' => 2, 'b' => 3, 'c' => 4}, 'instances' => [{'name' => 'external_db', 'address' => '192.168.15.4'}], 'networks' => {'a' => 2, 'b' => 3}}}}],
          instances: 1,
          static_ips: ['192.168.1.10'],
          properties: {}
      )
      job_spec['azs'] = ['z1']
      job_spec['networks'] << {
          'name' => 'dynamic-network',
          'default' => ['dns', 'gateway']
      }
      job_spec
    end

    let(:job_with_link_properties_not_defined_in_release_properties) do
      job_spec = Bosh::Spec::Deployments.simple_job(
          name: 'jobby',
          templates: [{'name' => 'provider', 'properties' => {'doesntExist' => 'someValue'}}],
          instances: 1,
          static_ips: ['192.168.1.10'],
          properties: {}
      )
      job_spec['azs'] = ['z1']
      job_spec['networks'] << {
          'name' => 'dynamic-network',
          'default' => ['dns', 'gateway']
      }
      job_spec
    end

    it 'should not raise an error when consuming links without properties' do
      manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
      manifest['releases'][0]['version'] = '0+dev.1'
      manifest['jobs'] = [job_with_nil_properties]

      out, exit_code = deploy_simple_manifest(manifest_hash: manifest, failure_expected: true, return_exit_code: true)

      expect(exit_code).to eq(0)
    end

    it 'should not raise an error when a deployment template property is not defined in the release properties' do
      manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
      manifest['releases'][0]['version'] = '0+dev.1'
      manifest['jobs'] = [job_with_link_properties_not_defined_in_release_properties]

      out, exit_code = deploy_simple_manifest(manifest_hash: manifest, failure_expected: true, return_exit_code: true)

      expect(exit_code).to eq(0)
    end

    it 'should be able to resolve a manual configuration in a consumes link' do
      manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
      manifest['jobs'] = [job_with_manual_consumes_link]

      out, exit_code = deploy_simple_manifest(manifest_hash: manifest, failure_expected: true, return_exit_code: true)
      expect(exit_code).to eq(0)

      link_vm = director.vm('property_job', '0')

      template = YAML.load(link_vm.read_job_template('consumer', 'config.yml'))

      expect(template['a']).to eq(2)
      expect(template['b']).to eq(3)
      expect(template['c']).to eq(4)
    end
  end

  context 'when link is not satisfied in deployment' do
    let(:bad_properties_job_spec) do
      job_spec = Bosh::Spec::Deployments.simple_job(
          name: 'api_server_with_bad_link_types',
          templates: [{'name' => 'api_server_with_bad_link_types'}],
          instances: 1,
          static_ips: ['192.168.1.10']
      )
      job_spec['azs'] = ['z1']
      job_spec['networks'] << {
          'name' => 'dynamic-network',
          'default' => ['dns', 'gateway']
      }
      job_spec
    end

    it 'should show all errors' do
      manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
      manifest['releases'][0]['version'] = '0+dev.1'
      manifest['jobs'] = [bad_properties_job_spec]

      out, exit_code = deploy_simple_manifest(manifest_hash: manifest, failure_expected: true, return_exit_code: true)

      expect(exit_code).not_to eq(0)
      expect(out).to include("Error 100: Unable to process links for deployment. Errors are:")
      expect(out).to include("- \"Can't find link with type 'bad_link' for job 'api_server_with_bad_link_types' in deployment 'simple'\"")
      expect(out).to include("- \"Can't find link with type 'bad_link_2' for job 'api_server_with_bad_link_types' in deployment 'simple'\"")
      expect(out).to include("- \"Can't find link with type 'bad_link_3' for job 'api_server_with_bad_link_types' in deployment 'simple'\"")
    end
  end
end
