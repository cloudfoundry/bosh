require_relative '../spec_helper'

describe 'Links', type: :integration do
  with_reset_sandbox_before_each

  def upload_links_release
    FileUtils.cp_r(LINKS_RELEASE_TEMPLATE, ClientSandbox.links_release_dir, :preserve => true)
    bosh_runner.run_in_dir('create-release --force', ClientSandbox.links_release_dir)
    bosh_runner.run_in_dir('upload-release', ClientSandbox.links_release_dir)
  end

  def should_contain_network_for_job(job, template, pattern)
    my_api_instance = director.instance(job, '0', deployment_name: 'simple')
    template = YAML.load(my_api_instance.read_job_template(template, 'config.yml'))

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
        static_ips: ['192.168.1.13'],
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
        instances = director.instances
        link_instance = director.find_instance(instances, 'other2', '0')
        template = YAML.load(link_instance.read_job_template('http_proxy_with_requires', 'config/config.yml'))
        expect(template['links']).to contain_exactly(["address", "192.168.1.2"], ["properties", {"listen_port"=>8082, "name_space"=>{"prop_a"=>"job_value"}, "fibonacci"=>1}])

        link_instance = director.find_instance(instances, 'new_job', '0')
        template = YAML.load(link_instance.read_job_template('http_proxy_with_requires', 'config/config.yml'))
        expect(template['links']).to contain_exactly(["address", "192.168.1.4"], ["properties", {"listen_port"=>9999, "name_space"=>{"prop_a"=>"default"}}])
      end
    end

    context 'when link is not defined in provides spec but specified in manifest' do
      let(:consume_job) do
        job_spec = Bosh::Spec::Deployments.simple_job(
          name: 'consume_job',
          templates: [
            {'name' => 'consumer', 'provides'=>{'consumer_resource' => {'from' => 'consumer'}}}
          ],
          instances: 1
        )
        job_spec['azs'] = ['z1']
        job_spec
      end

      let(:manifest) do
        manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
        manifest['jobs'] = [consume_job]
        manifest
      end

      it 'should raise an error' do
        expect { deploy_simple_manifest(manifest_hash: manifest) }.to raise_error(/Job 'consume_job' does not provide link 'consumer_resource' in the release spec/)
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

        instances = director.instances
        link_instance = director.find_instance(instances, 'my_api', '0')
        mysql_0_instance = director.find_instance(instances, 'mysql', '0')
        mysql_1_instance = director.find_instance(instances, 'mysql', '1')

        template = YAML.load(link_instance.read_job_template('api_server', 'config.yml'))

        expect(template['databases']['main'].size).to eq(2)
        expect(template['databases']['main']).to contain_exactly(
            {
              'id' => "#{mysql_0_instance.id}",
              'name' => 'mysql',
              'index' => 0,
              'address' => "#{mysql_0_instance.id}.mysql.dynamic-network.simple.bosh"
            },
            {
              'id' => "#{mysql_1_instance.id}",
              'name' => 'mysql',
              'index' => 1,
              'address' => "#{mysql_1_instance.id}.mysql.dynamic-network.simple.bosh"
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
          expect(out).to include("Error: Cannot resolve link path 'simple.postgres.backup_database.backup_db' required for link 'optional_link_name' in instance group 'my_api' on job 'api_server_with_optional_links_1'")
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
          expect(out).to include("Succeeded")
        end
      end

      context 'when a job spec specifies an optional key in a provides link' do
        it 'should fail when uploading the release' do
          expect {
            bosh_runner.run("upload-release #{spec_asset('links_releases/corrupted_release_optional_provides-0+dev.1.tgz')}")
          }.to raise_error(RuntimeError, /Error: Link 'node1' of type 'node1' is a provides link, not allowed to have 'optional' key/)
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

            link_instance = director.instance('my_api', '0')
            template = YAML.load(link_instance.read_job_template('api_server_with_optional_links_1', 'config.yml'))

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

            link_instance = director.instance('my_api', '0')
            template = YAML.load(link_instance.read_job_template('api_server_with_optional_links_2', 'config.yml'))

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
            expect(out).to include("Error: Link path was not provided for required link 'db' in instance group 'my_api'")
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

          link_instance = director.instance('my_api', '0')
          template = YAML.load(link_instance.read_job_template('api_server_with_optional_links_2', 'config.yml'))

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
Error: Unable to render instance groups for deployment. Errors are:
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
Error: Unable to process links for deployment. Errors are:
  - Multiple instance groups provide links of type 'db'. Cannot decide which one to use for instance group 'optional_db'.
     simple.mysql.database.db
     simple.postgres.backup_database.backup_db
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

      it 'should successfully compile a release without complaining about missing links in sha2 mode', sha2: true do
        deploy_simple_manifest(manifest_hash: manifest)
        out = bosh_runner.run("export-release bosh-release/0+dev.1 toronto-os/1", deployment_name: 'simple')

        expect(out).to include('Preparing package compilation: Finding packages to compile')
        expect(out).to include('Compiling packages: pkg_2/8320802768871474e5630206aa606e3a22ae14096b5c7a836224c8480018cb8b')
        expect(out).to include('Compiling packages: pkg_3_depends_on_2/b34bd09030e9d6eff29b4cce9948ccbd7d8833bf757e64e4905b1d574bb7b849')
        expect(out).to include('copying packages: pkg_1/bb9cd0b267e39192bb6728192834f694a6199347b9b9528219c68e8bd1785cbe')
        expect(out).to include('copying packages: pkg_2/8320802768871474e5630206aa606e3a22ae14096b5c7a836224c8480018cb8b')
        expect(out).to include('copying packages: pkg_3_depends_on_2/b34bd09030e9d6eff29b4cce9948ccbd7d8833bf757e64e4905b1d574bb7b849')
        expect(out).to include('copying jobs: addon/33e54f840bf107e3ed940fda30336d89a654ef6903ebd64ab4731998e47f1a06')
        expect(out).to include('copying jobs: api_server/87508488cc2295169483f58302f001e7dbc97529f3b12809845259154faa521a')
        expect(out).to include('copying jobs: api_server_with_bad_link_types/d86da5e1b821668455a5bda4f3d6ef1d03995f3bb685236dbefecac59e79372c')
        expect(out).to include('copying jobs: api_server_with_bad_optional_links/a8a20ada9008ada7720bd74061de0a44c59cf81e0a2827c2b93873afee7b47fd')
        expect(out).to include('copying jobs: api_server_with_optional_db_link/2ba41548a719665e679f834243916fcdb8c03eaebb69a0d3f806d9c157c372f7')
        expect(out).to include('copying jobs: api_server_with_optional_links_1/2c64d33e3b4a941e2dba4f86e7568f6c9a954c7b313b6a6d69552bd7741325a7')
        expect(out).to include('copying jobs: api_server_with_optional_links_2/d67d7780b76c04a01403048c2565ef6fe871e0268596678d9bff355aecc314da')
        expect(out).to include('copying jobs: backup_database/d04ace47dcaa65e69fac6a3688b866845352a163d0dcfde0f2a0d02dd0293d8f')
        expect(out).to include('copying jobs: consumer/494eab835be50838c15f0ff6952fd1b10c79a99f3c593391679b5f0f2a2d305d')
        expect(out).to include('copying jobs: database/f6acdd0dc09c90a9a9d06032d176d479839ed52484ea31dbea72b9450e994136')
        expect(out).to include('copying jobs: database_with_two_provided_link_of_same_type/9e200cea9e07f1a92da7c5fd4735281b9d14817e220d97c909301f1895e5373b')
        expect(out).to include('copying jobs: http_endpoint_provider_with_property_types/11abffb51dc49ee44a1825f8911629c4cb7c02dd17057247826c8601cd234118')
        expect(out).to include('copying jobs: http_proxy_with_requires/fb01af8736f1ff43db6e507cc0f11cbba4ca75408a6f4ea614637f01ce2f93a4')
        expect(out).to include('copying jobs: http_server_with_provides/46f5cd44ad799db2be2624266c9a9487200ffa18a23bc83df64a19e1413f1e37')
        expect(out).to include('copying jobs: kv_http_server/11c28a822aa698ee9aa9af81ccf6dc67232e2ab25338aca252bac3e90d4e1d95')
        expect(out).to include('copying jobs: mongo_db/740fcbd346be1d9895d727608c66c2e73e2e850e888aa24f78830eb94d53de7a')
        expect(out).to include('copying jobs: node/2b6b3ec34ad9738007a6b861d776b2916e8868986cbe166d6225c508e320e4ad')
        expect(out).to include('copying jobs: provider/b9f01ed6fc017ab7f3bf4fc098828176685a40bc2cd1e786e04a978465c949d7')
        expect(out).to include('copying jobs: provider_fail/43ab3579d49542b999641880cb3f357f605758924a8ad1cefb52d10d03e49916')

        expect(out).to include('Succeeded')
      end

      it 'should successfully compile a release without complaining about missing links in sha1 mode', sha1: true do
        deploy_simple_manifest(manifest_hash: manifest)
        out = bosh_runner.run("export-release bosh-release/0+dev.1 toronto-os/1", deployment_name: 'simple')

        expect(out).to include('Preparing package compilation: Finding packages to compile')
        expect(out).to include('Compiling packages: pkg_2/fa48497a19f12e925b32fcb8f5ca2b42144e4444')
        expect(out).to include('Compiling packages: pkg_3_depends_on_2/2dfa256bc0b0750ae9952118c428b0dcd1010305')
        expect(out).to include('copying packages: pkg_1/7a4094dc99aa72d2d156d99e022d3baa37fb7c4b')
        expect(out).to include('copying packages: pkg_2/fa48497a19f12e925b32fcb8f5ca2b42144e4444')
        expect(out).to include('copying packages: pkg_3_depends_on_2/2dfa256bc0b0750ae9952118c428b0dcd1010305')
        expect(out).to include('copying jobs: addon/1c5442ca2a20c46a3404e89d16b47c4757b1f0ca')
        expect(out).to include('copying jobs: api_server/76ff26229b603294a6f540e53faf68a2424cdf59')
        expect(out).to include('copying jobs: api_server_with_bad_link_types/058b26819bd6561a75c2fed45ec49e671c9fbc6a')
        expect(out).to include('copying jobs: api_server_with_bad_optional_links/8a2485f1de3d99657e101fd269202c39cf3b5d73')
        expect(out).to include('copying jobs: api_server_with_optional_db_link/00831c288b4a42454543ff69f71360634bd06b7b')
        expect(out).to include('copying jobs: api_server_with_optional_links_1/0efc908dd04d84858e3cf8b75c326f35af5a5a98')
        expect(out).to include('copying jobs: api_server_with_optional_links_2/15f815868a057180e21dbac61629f73ad3558fec')
        expect(out).to include('copying jobs: backup_database/29322b71c9a475beae1249873d8f6e136335448b')
        expect(out).to include('copying jobs: consumer/142c10d6cd586cd9b092b2618922194b608160f7')
        expect(out).to include('copying jobs: database/f2929b306c9d89bede1b37cc27f8fa71bb1fd8e8')
        expect(out).to include('copying jobs: database_with_two_provided_link_of_same_type/7f4c5700b68fe4f59588c5ca09c3d4a9f8a93dda')
        expect(out).to include('copying jobs: http_endpoint_provider_with_property_types/30978e9fd0d29e52fe0369262e11fbcea1283889')
        expect(out).to include('copying jobs: http_proxy_with_requires/4592ccbff484de43750068a1b7eab120bcf80b50')
        expect(out).to include('copying jobs: http_server_with_provides/64244f12f2db2e7d93ccfbc13be744df87013389')
        expect(out).to include('copying jobs: kv_http_server/044ec02730e6d068ecf88a0d37fe48937687bdba')
        expect(out).to include('copying jobs: mongo_db/6a6e241c0bd5c203397f0213bee9d3d28a4ff35f')
        expect(out).to include('copying jobs: node/c12835da15038bedad6c49d20a2dda00375a0dc0')
        expect(out).to include('copying jobs: provider/e1ff4ff9a6304e1222484570a400788c55154b1c')
        expect(out).to include('copying jobs: provider_fail/314c385e96711cb5d56dd909a086563dae61bc37')

        expect(out).to include('Succeeded')
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

        link_instance = director.instance('my_api', '0')
        template = YAML.load(link_instance.read_job_template('api_server', 'config.yml'))

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

        link_instance = director.instance('my_api', '0')
        template = YAML.load(link_instance.read_job_template('api_server', 'config.yml'))

        postgres_instance = director.instance('postgres', '0')

        expect(template['databases']['main'].size).to eq(1)
        expect(template['databases']['main']).to contain_exactly(
             {
                 'id' => "#{postgres_instance.id}",
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
          # expect(director.vms('simple')).to eq([])
          expect(director.instances).to eq([])
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
          expect(director.instances).to eq([])
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

        link_instance = director.instance('my_api', '0')
        aliased_postgres_instance = director.instance('aliased_postgres', '0')

        template = YAML.load(link_instance.read_job_template('api_server', 'config.yml'))

        expect(template['databases']['main'].size).to eq(1)
        expect(template['databases']['main']).to contain_exactly(
           {
               'id' => "#{aliased_postgres_instance.id}",
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
        expect(director.instances).to eq([])
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

        link_instance = director.instance('new_api_job', '0')
        template = YAML.load(link_instance.read_job_template('api_server', 'config.yml'))

        new_aliased_job_instance = director.instance('new_aliased_job', '0')

        expect(template['databases']['main'].size).to eq(1)
        expect(template['databases']['main']).to contain_exactly(
           {
               'id' => "#{new_aliased_job_instance.id}",
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
        expect(director.instances).to eq([])
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

         first_deployment_instance = director.instance('first_deployment_node', '0', deployment_name: 'first')
         first_deployment_template = YAML.load(first_deployment_instance.read_job_template('node', 'config.yml'))

         second_manifest['jobs'][0]['instances'] = 2
         second_manifest['jobs'][0]['static_ips'] = ['192.168.1.12', '192.168.1.13']
         second_manifest['jobs'][0]['networks'][0]['static_ips'] = ['192.168.1.12', '192.168.1.13']

         deploy_simple_manifest(manifest_hash: second_manifest)

         second_deployment_instance = director.instance('second_deployment_node', '0', deployment_name: 'second')
         second_deployment_template = YAML.load(second_deployment_instance.read_job_template('node', 'config.yml'))
         expect(second_deployment_template['instances']['node1_bootstrap_address']).to eq(first_deployment_template['instances']['node1_bootstrap_address'])
       end

       context 'when user does not specify a network for consumes' do
         it 'should use default network' do
           deploy_simple_manifest(manifest_hash: first_manifest)
           deploy_simple_manifest(manifest_hash: second_manifest)

           second_deployment_instance = director.instance('second_deployment_node', '0', deployment_name: 'second')
           second_deployment_template = YAML.load(second_deployment_instance.read_job_template('node', 'config.yml'))

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

           second_deployment_instance = director.instance('second_deployment_node', '0', deployment_name: 'second')
           second_deployment_template = YAML.load(second_deployment_instance.read_job_template('node', 'config.yml'))

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

        context 'user has duplicate implicit links provided in two jobs over separate networks' do

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
        bosh_runner.run("upload-release #{spec_asset('links_releases/release_with_minimal_links-0+dev.1.tgz')}")
        manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
        manifest['releases'].clear
        manifest['releases'] << {
            'name' => 'release_with_minimal_links',
            'version' => '0+dev.1'
        }
        manifest['jobs'] = [job_consumes_link_spec, mysql_job_spec, postgres_job_spec]

        output_1, exit_code_1 = deploy_simple_manifest(manifest_hash: manifest, return_exit_code: true)
        expect(exit_code_1).to eq(0)
        expect(output_1).to match(/Creating missing vms: deployment-job\/[a-z0-9\-]+ \(0\)/)
        expect(output_1).to match(/Creating missing vms: mysql\/[a-z0-9\-]+ \(0\)/)
        expect(output_1).to match(/Creating missing vms: mysql\/[a-z0-9\-]+ \(1\)/)
        expect(output_1).to match(/Creating missing vms: postgres\/[a-z0-9\-]+ \(0\)/)

        expect(output_1).to match(/Updating instance deployment-job: deployment-job\/[a-z0-9\-]+ \(0\)/)
        expect(output_1).to match(/Updating instance mysql: mysql\/[a-z0-9\-]+ \(0\)/)
        expect(output_1).to match(/Updating instance mysql: mysql\/[a-z0-9\-]+ \(1\)/)
        expect(output_1).to match(/Updating instance postgres: postgres\/[a-z0-9\-]+ \(0\)/)


        # ####################################################################
        # 2- Deploy release version dev.2 where its jobs were updated to not have links
        bosh_runner.run("upload-release #{spec_asset('links_releases/release_with_minimal_links-0+dev.2.tgz')}")

        manifest['releases'].clear
        manifest['releases'] << {
            'name' => 'release_with_minimal_links',
            'version' => 'latest'
        }
        manifest['jobs'].clear
        manifest['jobs'] = [job_not_consuming_links_spec, mysql_job_spec, postgres_job_spec]

        output_2, exit_code_2 = deploy_simple_manifest(manifest_hash: manifest, return_exit_code: true)
        expect(exit_code_2).to eq(0)
        expect(output_2).to_not match(/Creating missing vms: deployment-job\/[a-z0-9\-]+ \(0\)/)
        expect(output_2).to_not match(/Creating missing vms: mysql\/[a-z0-9\-]+ \(0\)/)
        expect(output_2).to_not match(/Creating missing vms: mysql\/[a-z0-9\-]+ \(1\)/)
        expect(output_2).to_not match(/Creating missing vms: postgres\/[a-z0-9\-]+ \(0\)/)

        expect(output_2).to match(/Updating instance deployment-job: deployment-job\/[a-z0-9\-]+ \(0\)/)
        expect(output_2).to match(/Updating instance mysql: mysql\/[a-z0-9\-]+ \(0\)/)
        expect(output_2).to match(/Updating instance mysql: mysql\/[a-z0-9\-]+ \(1\)/)
        expect(output_2).to match(/Updating instance postgres: postgres\/[a-z0-9\-]+ \(0\)/)

        current_deployments = bosh_runner.run("deployments", json: true)
        #THERE IS WHITESPACE AT THE END OF THE TABLE. DO NOT REMOVE IT
        expect(table(current_deployments)).to eq([{'name' => 'simple', 'release_s' => 'release_with_minimal_links/0+dev.2', 'stemcell_s' => 'ubuntu-stemcell/1', 'team_s' => '', 'cloud_config' => 'latest'}])


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
        expect(output_3).to_not match(/Creating missing vms: deployment-job\/[a-z0-9\-]+ \(0\)/)
        expect(output_3).to_not match(/Creating missing vms: mysql\/[a-z0-9\-]+ \(0\)/)
        expect(output_3).to_not match(/Creating missing vms: mysql\/[a-z0-9\-]+ \(1\)/)
        expect(output_3).to_not match(/Creating missing vms: postgres\/[a-z0-9\-]+ \(0\)/)

        expect(output_3).to match(/Updating instance deployment-job: deployment-job\/[a-z0-9\-]+ \(0\)/)
        expect(output_3).to match(/Updating instance mysql: mysql\/[a-z0-9\-]+ \(0\)/)
        expect(output_3).to match(/Updating instance mysql: mysql\/[a-z0-9\-]+ \(1\)/)
        expect(output_3).to match(/Updating instance postgres: postgres\/[a-z0-9\-]+ \(0\)/)
      end

      it 'allows only the specified properties' do
        expect{ deploy_simple_manifest(manifest_hash: manifest) }.to_not raise_error
      end
    end

    context 'when resurrector tries to resurrect an VM with jobs that consume links', hm: true do
      with_reset_hm_before_each

      let(:links) do
        {
          'db' => {'from' => 'db'},
          'backup_db' => {'from' => 'backup_db'}
        }
      end

      it 'resurrects the VM and resolves links correctly', hm: true do
        deploy_simple_manifest(manifest_hash: manifest)

        instances = director.instances
        api_instance = director.find_instance(instances, 'my_api', '0')
        mysql_0_instance = director.find_instance(instances, 'mysql', '0')
        mysql_1_instance = director.find_instance(instances, 'mysql', '1')

        template = YAML.load(api_instance.read_job_template('api_server', 'config.yml'))

        expect(template['databases']['main'].size).to eq(2)
        expect(template['databases']['main']).to contain_exactly(
           {
             'id' => "#{mysql_0_instance.id}",
             'name' => 'mysql',
             'index' => 0,
             'address' => "#{mysql_0_instance.id}.mysql.dynamic-network.simple.bosh"
           },
           {
             'id' => "#{mysql_1_instance.id}",
             'name' => 'mysql',
             'index' => 1,
             'address' => "#{mysql_1_instance.id}.mysql.dynamic-network.simple.bosh"
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


        # ===========================================
        # After resurrection
        new_api_instance = director.kill_vm_and_wait_for_resurrection(api_instance)
        new_template = YAML.load(new_api_instance.read_job_template('api_server', 'config.yml'))
        expect(new_template['databases']['main'].size).to eq(2)
        expect(new_template['databases']['main']).to contain_exactly(
           {
             'id' => "#{mysql_0_instance.id}",
             'name' => 'mysql',
             'index' => 0,
             'address' => "#{mysql_0_instance.id}.mysql.dynamic-network.simple.bosh"
           },
           {
             'id' => "#{mysql_1_instance.id}",
             'name' => 'mysql',
             'index' => 1,
             'address' => "#{mysql_1_instance.id}.mysql.dynamic-network.simple.bosh"
           }
         )

        expect(new_template['databases']['backup']).to contain_exactly(
           {
             'name' => 'postgres',
             'az' => 'z1',
             'index' => 0,
             'address' => '192.168.1.12'
           }
         )
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
      runtime_config_file = yaml_file('runtime_config.yml', Bosh::Spec::Deployments.runtime_config_with_links)
      bosh_runner.run("update-runtime-config #{runtime_config_file.path}")
    end

    it 'should resolve links for addons' do
      manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
      manifest['releases'][0]['version'] = '0+dev.1'
      manifest['jobs'] = [mysql_job_spec]

      deploy_simple_manifest(manifest_hash: manifest)

      my_sql_instance = director.instance("mysql", '0', deployment_name: 'simple')
      template = YAML.load(my_sql_instance.read_job_template("addon", 'config.yml'))

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

      link_instance = director.instance('property_job', '0')

      template = YAML.load(link_instance.read_job_template('consumer', 'config.yml'))

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
      expect(out).to include("Error: Unable to process links for deployment. Errors are:")
      expect(out).to include("- Can't find link with type 'bad_link' for job 'api_server_with_bad_link_types' in deployment 'simple'")
      expect(out).to include("- Can't find link with type 'bad_link_2' for job 'api_server_with_bad_link_types' in deployment 'simple'")
      expect(out).to include("- Can't find link with type 'bad_link_3' for job 'api_server_with_bad_link_types' in deployment 'simple'")
    end
  end
end
