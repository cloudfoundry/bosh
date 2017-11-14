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

    template['databases'].select{|key| key == 'main' || key == 'backup_db'}.each do |_, database|
      database.each do |instance|
          expect(instance['address']).to match(pattern)
      end
    end
  end

  def send_director_api_request(url_path, query, method)
    director_url = URI(current_sandbox.director_url)
    director_url.path = URI.escape(url_path)
    director_url.query = URI.escape(query)

    req = Net::HTTP::Get.new(director_url)
    req.basic_auth 'test', 'test'

    res = Net::HTTP.start(director_url.hostname, director_url.port,
    :use_ssl => true,
    :verify_mode => OpenSSL::SSL::VERIFY_PEER,
    :ca_file => current_sandbox.certificate_path) {|http|
      http.request(req)
    }
  end

  let(:cloud_config) do
    cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config
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
    let(:implied_instance_group_spec) do
      spec = Bosh::Spec::NewDeployments.simple_instance_group(
        name: 'my_api',
        jobs: [{'name' => 'api_server'}],
        instances: 1
      )
      spec['azs'] = ['z1']
      spec
    end

    let(:api_instance_group_spec) do
      spec = Bosh::Spec::NewDeployments.simple_instance_group(
        name: 'my_api',
        jobs: [{'name' => 'api_server', 'consumes' => links}],
        instances: 1
      )
      spec['azs'] = ['z1']
      spec
    end

    let(:mysql_instance_group_spec) do
      spec = Bosh::Spec::NewDeployments.simple_instance_group(
        name: 'mysql',
        jobs: [{'name' => 'database'}],
        instances: 2,
        static_ips: ['192.168.1.10', '192.168.1.11']
      )
      spec['azs'] = ['z1']
      spec['networks'] << {
        'name' => 'dynamic-network',
        'default' => ['dns', 'gateway']
      }
      spec
    end

    let(:postgres_instance_group_spec) do
      spec = Bosh::Spec::NewDeployments.simple_instance_group(
        name: 'postgres',
        jobs: [{'name' => 'backup_database'}],
        instances: 1,
        static_ips: ['192.168.1.12']
      )
      spec['azs'] = ['z1']
      spec
    end

    let(:aliased_instance_group_spec) do
      spec = Bosh::Spec::NewDeployments.simple_instance_group(
        name: 'aliased_postgres',
        jobs: [{'name' => 'backup_database', 'provides' => {'backup_db' => {'as' => 'link_alias'}}}],
        instances: 1,
      )
      spec['azs'] = ['z1']
      spec
    end

    let(:mongo_db_spec)do
      spec = Bosh::Spec::NewDeployments.simple_instance_group(
        name: 'mongo',
        jobs: [{'name' => 'mongo_db'}],
        instances: 1,
        static_ips: ['192.168.1.13'],
      )
      spec['azs'] = ['z1']
      spec
    end

    let(:manifest) do
      manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
      manifest['instance_groups'] = [api_instance_group_spec, mysql_instance_group_spec, postgres_instance_group_spec]
      manifest
    end

    let(:links) {{}}

    context 'when job consumes link with nested properties' do

      let(:link_instance_group_spec) do
        spec = Bosh::Spec::NewDeployments.simple_instance_group(
          name: 'my_links',
          jobs: [
            {'name' => 'provider', 'properties' => {'b' => 'value_b', 'nested' => {'three' => 'bar'}}},
            {'name' => 'consumer'}],
          instances: 1
        )
        spec['azs'] = ['z1']
        spec
      end

      it 'respects default properties' do
        manifest['instance_groups'] = [link_instance_group_spec]
        deploy_simple_manifest(manifest_hash: manifest)

        link_instance = director.find_instance(director.instances, 'my_links', '0')

        template = YAML.load(link_instance.read_job_template('consumer', 'config.yml'))


        expect(template['a']).to eq('default_a')
        expect(template['b']).to eq('value_b')
        expect(template['c']).to eq('default_c')

        expect(template['nested'].size).to eq(3)
        expect(template['nested']).to eq(
          {
            'one' => 'default_nested.one',
            'two' => 'default_nested.two',
            'three' => 'bar',
          }
        )
      end
    end

    context 'properties with aliased links' do
      let(:db3_instance_group) do
        spec = Bosh::Spec::NewDeployments.simple_instance_group(
            name: 'db3',
            jobs: [
                {'name' => 'http_server_with_provides', 'provides' => {'http_endpoint' => {'as' => 'http_endpoint2', 'shared' => true}}},
                {'name' => 'kv_http_server'}
            ],
            instances: 1
        )
        spec['azs'] = ['z1']
        spec['properties'] = {'listen_port' => 8082, 'kv_http_server' => {'listen_port' => 8081}, 'name_space' => {'prop_a' => 'job_value', 'fibonacci' => 1}}
        spec
      end

      let(:other2_instance_group) do
        spec = Bosh::Spec::NewDeployments.simple_instance_group(
            name: 'other2',
            jobs: [
                {'name' => 'http_proxy_with_requires', 'properties' => {'http_proxy_with_requires.listen_port' => 21}, 'consumes' => {'proxied_http_endpoint' => {'from' => 'http_endpoint2', 'shared' => true}, 'logs_http_endpoint' => nil}},
                {'name' => 'http_server_with_provides', 'properties' => {'listen_port' => 8446}}
            ],
            instances: 1
        )
        spec['azs'] = ['z1']
        spec
      end

      let(:new_instance_group) do
        job_spec = Bosh::Spec::NewDeployments.simple_instance_group(
            name: 'new_job',
            jobs: [
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
        manifest['instance_groups'] = [db3_instance_group, other2_instance_group, new_instance_group]
        manifest['properties'] = {'listen_port' => 9999}
        manifest
      end

      it 'is able to pick the right value for the property from global, job, template and default values' do
        deploy_simple_manifest(manifest_hash: manifest)
        instances = director.instances
        link_instance = director.find_instance(instances, 'other2', '0')
        template = YAML.load(link_instance.read_job_template('http_proxy_with_requires', 'config/config.yml'))
        expect(template['links']).to contain_exactly(['address', '192.168.1.2'], ['properties', {'listen_port' =>8082, 'name_space' =>{'prop_a' => 'job_value'}, 'fibonacci' =>1}])

        link_instance = director.find_instance(instances, 'new_job', '0')
        template = YAML.load(link_instance.read_job_template('http_proxy_with_requires', 'config/config.yml'))
        expect(template['links']).to contain_exactly(['address', '192.168.1.4'], ['properties', {'listen_port' =>9999, 'name_space' =>{'prop_a' => 'default'}}])
      end
    end

    context 'when link is not defined in provides spec but specified in manifest' do
      let(:consume_instance_group) do
        spec = Bosh::Spec::NewDeployments.simple_instance_group(
          name: 'consume_job',
          jobs: [
            {'name' => 'consumer', 'provides'=>{'consumer_resource' => {'from' => 'consumer'}}}
          ],
          instances: 1
        )
        spec['azs'] = ['z1']
        spec
      end

      let(:manifest) do
        manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
        manifest['instance_groups'] = [consume_instance_group]
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

      it 'links api lists link provider' do
        deploy_simple_manifest(manifest_hash: manifest)

        response = send_director_api_request("/link_providers", "deployment=simple", 'GET')

        expect(response).not_to eq(nil)

        expect(response.code).to eq('200')
        response_body = JSON.parse(response.read_body)

        expect(response_body).to_not eq({}.to_json)
        expect(response_body[0]['deployment']).to eq(manifest['name'])
        expect(response_body[0]['instance_group']).to eq('mysql')
        expect(response_body[0]['link_provider_definition']).to eq({'type' => 'db', 'name' => 'db'})
        expect(response_body[0]['owner_object']).to eq({"type" => 'Job', "name" => 'database'})
        expect(response_body[0]['content']).to_not eq({})
        expect(response_body[0]['shared']).to eq(false)

        id = response_body[1]['content'][/id":"([a-z0-9-]*)"/,1]

        body_one = {
          'id'=>2,
          'name'=>'backup_db',
          'shared'=>false,
          'deployment'=>'simple',
          'instance_group'=>'postgres',
          'content'=>"{\"deployment_name\":\"simple\",\"domain\":\"bosh\",\"default_network\":\"a\",\"networks\":[\"a\"],\"instance_group\":\"postgres\",\"properties\":{\"foo\":\"backup_bar\"},\"instances\":[{\"name\":\"postgres\",\"id\":\"#{id}\",\"index\":0,\"bootstrap\":true,\"az\":\"z1\",\"address\":\"192.168.1.12\",\"addresses\":{\"a\":\"192.168.1.12\"},\"dns_addresses\":{\"a\":\"192.168.1.12\"}}]}",
          'link_provider_definition'=>{'type'=>'db', 'name'=>'backup_db'},
          'owner_object'=> {
            'type'=>'Job',
            'name'=>'backup_database',
          }
        }
        expect(response_body[1]).to eq(body_one)
      end

      context 'deploy of manifest' do
        let(:links) do
          {
            'db' => {'from' => 'link_alias'},
            'backup_db' => {'from' => 'link_alias'},
          }
        end

        let(:optional_links) do
          {
            'db' => {'from' => 'link_alias'}
          }
        end

        let(:api_job_spec) do
          job_spec = Bosh::Spec::NewDeployments.simple_instance_group(
            name: 'my_api',
            jobs: [{'name' => 'api_server', 'consumes' => links}],
            instances: 1
          )
          job_spec['azs'] = ['z1']
          job_spec
        end

        let(:aliased_job_spec) do
          job_spec = Bosh::Spec::NewDeployments.simple_instance_group(
            name: 'aliased_postgres',
            jobs: [{'name' => 'backup_database', 'provides' => {'backup_db' => {'as' => 'link_alias'}}}],
            instances: 1,
          )
          job_spec['azs'] = ['z1']
          job_spec
          end

        let(:api_server_with_optional_db_links)do
          job_spec = Bosh::Spec::NewDeployments.simple_instance_group(
            name: 'optional_db',
            jobs: [{'name' => 'api_server_with_optional_db_link', 'consumes' => optional_links}],
            instances: 1,
            static_ips: ['192.168.1.13']
          )
          job_spec['azs'] = ['z1']
          job_spec
        end

        let(:manifest) do
          manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
          manifest['instance_groups'] = [api_server_with_optional_db_links, api_job_spec, aliased_job_spec]
          manifest
        end

        before do
          deploy_simple_manifest(manifest_hash: manifest)
        end

        it 'should create a provider and consumer' do
          response = send_director_api_request("/link_providers", "deployment=simple", 'GET')

          expect(response).not_to eq(nil)

          expect(response.code).to eq('200')
          response_body = JSON.parse(response.read_body)
          expect(response_body.count).to eq(1)

          response = send_director_api_request("/link_consumers", "deployment=simple", 'GET')

          expect(response).not_to eq(nil)
          expect(response.code).to eq('200')
          response_body = JSON.parse(response.read_body)
          expect(response_body.count).to eq(2)
        end

        context 'without provider and consumer jobs' do
          let(:manifest) do
            manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
            manifest['instance_groups'] = []
            manifest
          end

          it 'has no providers' do
            deploy_simple_manifest(manifest_hash: manifest)

            response = send_director_api_request("/link_providers", "deployment=simple", 'GET')

            expect(response).not_to eq(nil)

            expect(response.code).to eq('200')
            response_body = JSON.parse(response.read_body)
            expect(response_body.count).to eq(0)
          end

          it 'has no consumers' do
            deploy_simple_manifest(manifest_hash: manifest)

            response = send_director_api_request("/link_consumers", "deployment=simple", 'GET')

            expect(response).not_to eq(nil)
            expect(response.code).to eq('200')
            response_body = JSON.parse(response.read_body)
            expect(response_body.count).to eq(0)
          end
        end

        context 'with jobs but without links' do
          let(:optional_links) do
            {}
          end

          it 'has no providers' do
            manifest['instance_groups'] = [api_server_with_optional_db_links]
            deploy_simple_manifest(manifest_hash: manifest)

            response = send_director_api_request("/link_providers", "deployment=simple", 'GET')

            expect(response).not_to eq(nil)
            expect(response.code).to eq('200')
            response_body = JSON.parse(response.read_body)
            expect(response_body.count).to eq(0)
          end

          it 'has no consumers' do
            manifest['instance_groups'] = [aliased_job_spec]
            deploy_simple_manifest(manifest_hash: manifest)

            response = send_director_api_request("/link_consumers", "deployment=simple", 'GET')

            expect(response).not_to eq(nil)
            expect(response.code).to eq('200')
            response_body = JSON.parse(response.read_body)
            expect(response_body.count).to eq(0)
          end
        end

        context 'with same jobs but different link alias' do
          let(:links2) do
            {
              'db' => {'from'=>'link_alias2'},
              'backup_db' => {'from' => 'link_alias2'},
            }
          end

          let(:optional_links2) do
            {
              'db' => {'from' => 'link_alias2'}
            }
          end

          let(:api_job_spec2) do
            spec = Bosh::Spec::NewDeployments.simple_instance_group(
              name: 'my_api',
              jobs: [{'name' => 'api_server', 'consumes' => links2}],
              instances: 1
            )
            spec['azs'] = ['z1']
            spec
          end

          let(:aliased_job_spec2) do
            spec = Bosh::Spec::NewDeployments.simple_instance_group(
              name: 'aliased_postgres',
              jobs: [{'name' => 'backup_database', 'provides' => {'backup_db' => {'as' => 'link_alias2'}}}],
              instances: 1,
            )
            spec['azs'] = ['z1']
            spec
          end

          let(:api_server_with_optional_db_links2)do
            spec = Bosh::Spec::NewDeployments.simple_instance_group(
              name: 'optional_db',
              jobs: [{'name' => 'api_server_with_optional_db_link', 'consumes' => optional_links2}],
              instances: 1,
              static_ips: ['192.168.1.13']
            )
            spec['azs'] = ['z1']
            spec
          end

          let(:new_manifest) do
            manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
            manifest['instance_groups'] = [api_server_with_optional_db_links2, api_job_spec2, aliased_job_spec2]
            manifest
          end

          it 'still has a new provider with updated link' do
            response = send_director_api_request("/link_providers", "deployment=simple", 'GET')
            response_body = JSON.parse(response.read_body)
            original_provider_id = response_body[0]['id']
            original_provider_link_name = response_body[0]['link_provider_definition']['name']

            deploy_simple_manifest(manifest_hash: new_manifest)

            response = send_director_api_request("/link_providers", "deployment=simple", 'GET')

            expect(response).not_to eq(nil)
            expect(response.code).to eq('200')
            response_body = JSON.parse(response.read_body)
            expect(response_body.count).to eq(1)
            expect(response_body[0]['id']).to_not eq(original_provider_id)
            expect(response_body[0]['link_provider_definition']['name']).to eq(original_provider_link_name)
          end

          it 'still has the same consumers' do
            response = send_director_api_request("/link_consumers", "deployment=simple", 'GET')
            response_body = JSON.parse(response.read_body)
            original_consumer_ids = []
            response_body.each do |consumer|
              original_consumer_ids << consumer['id']
            end

            deploy_simple_manifest(manifest_hash: new_manifest)

            response = send_director_api_request("/link_consumers", "deployment=simple", 'GET')

            expect(response).not_to eq(nil)
            expect(response.code).to eq('200')
            response_body = JSON.parse(response.read_body)
            expect(response_body.count).to eq(2)
            expect(response_body[0]['id']).to eq(original_consumer_ids[0])
            expect(response_body[1]['id']).to eq(original_consumer_ids[1])
          end
        end
      end
    end

    context 'when dealing with optional links' do

      let(:api_instance_group_with_optional_links_spec_1) do
        spec = Bosh::Spec::NewDeployments.simple_instance_group(
            name: 'my_api',
            jobs: [{'name' => 'api_server_with_optional_links_1', 'consumes' => links}],
            instances: 1
        )
        spec['azs'] = ['z1']
        spec
      end

      let(:api_instance_group_with_optional_links_spec_2) do
        spec = Bosh::Spec::NewDeployments.simple_instance_group(
            name: 'my_api',
            jobs: [{'name' => 'api_server_with_optional_links_2', 'consumes' => links}],
            instances: 1
        )
        spec['azs'] = ['z1']
        spec
      end

      let(:manifest) do
        manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
        manifest['instance_groups'] = [api_instance_group_with_optional_links_spec_1, mysql_instance_group_spec, postgres_instance_group_spec]
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
          expect(out).to include('Succeeded')
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
            manifest['instance_groups'] = [api_instance_group_with_optional_links_spec_2, mysql_instance_group_spec, postgres_instance_group_spec]
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
          manifest['instance_groups'] = [api_instance_group_with_optional_links_spec_2, mysql_instance_group_spec, postgres_instance_group_spec]
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
        let(:api_instance_group_with_bad_optional_links) do
          spec = Bosh::Spec::NewDeployments.simple_instance_group(
              name: 'my_api',
              jobs: [{'name' => 'api_server_with_bad_optional_links'}],
              instances: 1
          )
          spec['azs'] = ['z1']
          spec
        end

        let(:manifest) do
          manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
          manifest['instance_groups'] = [api_instance_group_with_bad_optional_links]
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
          spec = Bosh::Spec::NewDeployments.simple_instance_group(
              name: 'optional_db',
              jobs: [{'name' => 'api_server_with_optional_db_link'}],
              instances: 1,
              static_ips: ['192.168.1.13']
          )
          spec['azs'] = ['z1']
          spec
        end

        let(:manifest) do
          manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
          manifest['instance_groups'] = [api_server_with_optional_db_links, mysql_instance_group_spec, postgres_instance_group_spec]
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
        manifest['instance_groups'] = [mongo_db_spec]

        # We manually change the deployment manifest release version, beacuse of w weird issue where
        # the uploaded release version is `0+dev.1` and the release version in the deployment manifest
        # is `0.1-dev`
        manifest['releases'][0]['version'] = '0+dev.1'

        manifest
      end

      it 'should successfully compile a release without complaining about missing links in sha2 mode', sha2: true do
        deploy_simple_manifest(manifest_hash: manifest)
        out = bosh_runner.run('export-release bosh-release/0+dev.1 toronto-os/1', deployment_name: 'simple')

        expect(out).to include('Preparing package compilation: Finding packages to compile')
        expect(out).to match(/Compiling packages: pkg_2\/[a-f0-9]+/)
        expect(out).to match(/Compiling packages: pkg_3_depends_on_2\/[a-f0-9]+/)
        expect(out).to match(/copying packages: pkg_1\/[a-f0-9]+/)
        expect(out).to match(/copying packages: pkg_3_depends_on_2\/[a-f0-9]+/)
        expect(out).to match(/copying jobs: addon\/[a-f0-9]+/)
        expect(out).to match(/copying jobs: api_server\/[a-f0-9]+/)
        expect(out).to match(/copying jobs: api_server_with_bad_link_types\/[a-f0-9]+/)
        expect(out).to match(/copying jobs: api_server_with_bad_optional_links\/[a-f0-9]+/)
        expect(out).to match(/copying jobs: api_server_with_optional_db_link\/[a-f0-9]+/)
        expect(out).to match(/copying jobs: api_server_with_optional_links_1\/[a-f0-9]+/)
        expect(out).to match(/copying jobs: api_server_with_optional_links_2\/[a-f0-9]+/)
        expect(out).to match(/copying jobs: backup_database\/[a-f0-9]+/)
        expect(out).to match(/copying jobs: consumer\/[a-f0-9]+/)
        expect(out).to match(/copying jobs: database\/[a-f0-9]+/)
        expect(out).to match(/copying jobs: database_with_two_provided_link_of_same_type\/[a-f0-9]+/)
        expect(out).to match(/copying jobs: http_endpoint_provider_with_property_types\/[a-f0-9]+/)
        expect(out).to match(/copying jobs: http_proxy_with_requires\/[a-f0-9]+/)
        expect(out).to match(/copying jobs: http_server_with_provides\/[a-f0-9]+/)
        expect(out).to match(/copying jobs: kv_http_server\/[a-f0-9]+/)
        expect(out).to match(/copying jobs: mongo_db\/[a-f0-9]+/)
        expect(out).to match(/copying jobs: node\/[a-f0-9]+/)
        expect(out).to match(/copying jobs: provider\/[a-f0-9]+/)
        expect(out).to match(/copying jobs: provider_fail\/[a-f0-9]+/)
        expect(out).to match(/copying jobs: tcp_proxy_with_requires\/[a-f0-9]+/)
        expect(out).to match(/copying jobs: tcp_server_with_provides\/[a-f0-9]+/)

        expect(out).to include('Succeeded')
      end

      it 'should successfully compile a release without complaining about missing links in sha1 mode', sha1: true do
        deploy_simple_manifest(manifest_hash: manifest)
        out = bosh_runner.run('export-release bosh-release/0+dev.1 toronto-os/1', deployment_name: 'simple')

        expect(out).to include('Preparing package compilation: Finding packages to compile')
        expect(out).to match(/Compiling packages: pkg_2\/[a-f0-9]+/)
        expect(out).to match(/Compiling packages: pkg_3_depends_on_2\/[a-f0-9]+/)
        expect(out).to match(/copying packages: pkg_1\/[a-f0-9]+/)
        expect(out).to match(/copying packages: pkg_2\/[a-f0-9]+/)
        expect(out).to match(/copying packages: pkg_3_depends_on_2\/[a-f0-9]+/)
        expect(out).to match(/copying jobs: addon\/[a-f0-9]+/)
        expect(out).to match(/copying jobs: api_server\/[a-f0-9]+/)
        expect(out).to match(/copying jobs: api_server_with_bad_link_types\/[a-f0-9]+/)
        expect(out).to match(/copying jobs: api_server_with_bad_optional_links\/[a-f0-9]+/)
        expect(out).to match(/copying jobs: api_server_with_optional_db_link\/[a-f0-9]+/)
        expect(out).to match(/copying jobs: api_server_with_optional_links_1\/[a-f0-9]+/)
        expect(out).to match(/copying jobs: api_server_with_optional_links_2\/[a-f0-9]+/)
        expect(out).to match(/copying jobs: backup_database\/[a-f0-9]+/)
        expect(out).to match(/copying jobs: consumer\/[a-f0-9]+/)
        expect(out).to match(/copying jobs: database\/[a-f0-9]+/)
        expect(out).to match(/copying jobs: database_with_two_provided_link_of_same_type\/[a-f0-9]+/)
        expect(out).to match(/copying jobs: http_endpoint_provider_with_property_types\/[a-f0-9]+/)
        expect(out).to match(/copying jobs: http_proxy_with_requires\/[a-f0-9]+/)
        expect(out).to match(/copying jobs: http_server_with_provides\/[a-f0-9]+/)
        expect(out).to match(/copying jobs: kv_http_server\/[a-f0-9]+/)
        expect(out).to match(/copying jobs: mongo_db\/[a-f0-9]+/)
        expect(out).to match(/copying jobs: node\/[a-f0-9]+/)
        expect(out).to match(/copying jobs: provider\/[a-f0-9]+/)
        expect(out).to match(/copying jobs: provider_fail\/[a-f0-9]+/)
        expect(out).to match(/copying jobs: tcp_proxy_with_requires\/[a-f0-9]+/)
        expect(out).to match(/copying jobs: tcp_server_with_provides\/[a-f0-9]+/)

        expect(out).to include('Succeeded')
      end
    end

    context 'when consumes link is renamed by from key' do
      let(:manifest) do
        manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
        manifest['instance_groups'] = [api_instance_group_spec, mongo_db_spec, mysql_instance_group_spec]
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

      it 'links api lists link consumer' do
        deploy_simple_manifest(manifest_hash: manifest)

        response = send_director_api_request("/link_consumers", "deployment=simple", 'GET')

        expect(response).not_to eq(nil)

        expect(response.code).to eq('200')
        response_body = JSON.parse(response.read_body)

        expect(response_body).to_not eq({}.to_json)
        expect(response_body.count).to eq(1)
        expect(response_body[0]['deployment']).to eq(manifest['name'])
        expect(response_body[0]['instance_group']).to eq('my_api')
        expect(response_body[0]['owner_object']).to eq({"type" => 'Job','name'=>'api_server'})
      end

    end

    context 'deployment job does not have templates' do
      let(:first_node_instance_group_spec) do
        spec = Bosh::Spec::NewDeployments.simple_instance_group(
            name: 'first_node',
            jobs: [],
            instances: 1,
            static_ips: ['192.168.1.10']
        )
        spec['azs'] = ['z1']
        spec
      end


      let(:manifest) do
        manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
        manifest['instance_groups'] = [first_node_instance_group_spec]
        manifest
      end

      it 'renders link data in job template' do
        deploy_simple_manifest(manifest_hash: manifest)
      end
    end

    context 'when release job requires and provides same link' do
      let(:first_node_instance_group_spec) do
        spec = Bosh::Spec::NewDeployments.simple_instance_group(
          name: 'first_node',
          jobs: [{'name' => 'node', 'consumes' => first_node_links}],
          instances: 1,
          static_ips: ['192.168.1.10']
        )
        spec['azs'] = ['z1']
        spec
      end

      let(:first_node_links) do
        {
          'node1' => {'from' => 'node1'},
          'node2' => {'from' => 'node2'}
        }
      end

      let(:second_node_instance_group_spec) do
        spec = Bosh::Spec::NewDeployments.simple_instance_group(
          name: 'second_node',
          jobs: [{'name' => 'node', 'consumes' => second_node_links}],
          instances: 1,
          static_ips: ['192.168.1.11']
        )
        spec['azs'] = ['z1']
        spec
      end
      let(:second_node_links) do
        {
          'node1' => {'from' => 'node1'},
          'node2' => {'from' => 'node2'}
        }
      end

      let(:manifest) do
        manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
        manifest['instance_groups'] = [first_node_instance_group_spec, second_node_instance_group_spec]
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
        manifest['instance_groups'] = [implied_instance_group_spec, postgres_instance_group_spec]
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
          manifest['instance_groups'] = [implied_instance_group_spec, postgres_instance_group_spec, mysql_instance_group_spec]
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
        let(:instance_group_with_same_type_links) do
          spec = Bosh::Spec::NewDeployments.simple_instance_group(
              name: 'duplicate_link_type_job',
              jobs: [{'name' => 'database_with_two_provided_link_of_same_type'}],
              instances: 1
          )
          spec['azs'] = ['z1']
          spec
        end

        let(:manifest) do
          manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
          manifest['instance_groups'] = [implied_instance_group_spec, instance_group_with_same_type_links]
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
        manifest['instance_groups'] = [api_instance_group_spec, aliased_instance_group_spec]
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

      context 'when two co-located jobs consume two links with the same name, where each is provided by a different job on the same instance group' do
        let(:manifest) do
          manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
          manifest['instance_groups'] = [provider_instance_group, consumer_instance_group]
          manifest
        end

        let(:provider_instance_group) do
          spec = Bosh::Spec::NewDeployments.simple_instance_group(
            name: 'provider_instance_group',
            jobs: [{
                          'name' => 'http_server_with_provides',
                          'properties' => {
                            'listen_port' => 11111,
                            'name_space' => {
                              'prop_a' => 'http_provider_some_prop_a'
                            }
                          },
                          'provides' => {'http_endpoint' => {'as' => 'link_http_alias'}}
                        },
                        {
                          'name' => 'tcp_server_with_provides',
                          'properties' => {
                            'listen_port' => 77777,
                            'name_space' => {
                              'prop_a' => 'tcp_provider_some_prop_a'
                            }
                          },
                          'provides' => {'http_endpoint' => {'as' => 'link_tcp_alias'}}
                        }

            ],
            instances: 1
          )
          spec['azs'] = ['z1']
          spec
        end

        let(:consumer_instance_group) do
          spec = Bosh::Spec::NewDeployments.simple_instance_group(
            name: 'consumer_instance_group',
            jobs: [
              {'name' => 'http_proxy_with_requires', 'consumes' => {'proxied_http_endpoint' => {'from' => 'link_http_alias'}}},
              {'name' => 'tcp_proxy_with_requires', 'consumes' => {'proxied_http_endpoint' => {'from' => 'link_tcp_alias'}}},
            ],
            instances: 1
          )
          spec['azs'] = ['z1']
          spec
        end

        it 'each job should get the correct link' do
          deploy_simple_manifest(manifest_hash: manifest)

          consumer_instance_group = director.instance('consumer_instance_group', '0')

          http_template = YAML.load(consumer_instance_group.read_job_template('http_proxy_with_requires', 'config/config.yml'))
          tcp_template = YAML.load(consumer_instance_group.read_job_template('tcp_proxy_with_requires', 'config/config.yml'))

          expect(http_template['links']['properties']['listen_port']).to eq(11111)
          expect(http_template['links']['properties']['name_space']['prop_a']).to eq('http_provider_some_prop_a')

          expect(tcp_template['links']['properties']['listen_port']).to eq(77777)
          expect(tcp_template['links']['properties']['name_space']['prop_a']).to eq('tcp_provider_some_prop_a')

        end
      end

      context 'when two co-located jobs consume two links with the same name, where each is provided by the same job on different instance groups' do
        let(:manifest) do
          manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
          manifest['instance_groups'] = [provider1_http, provider2_http, consumer_instance_group]
          manifest
        end

        let(:provider1_http) do
          spec = Bosh::Spec::NewDeployments.simple_instance_group(
            name: 'provider1_http_instance_group',
            jobs: [{
                          'name' => 'http_server_with_provides',
                          'properties' => {
                            'listen_port' => 11111,
                            'name_space' => {
                              'prop_a' => '1_some_prop_a'
                            }
                          },
                          'provides' => {'http_endpoint' => {'as' => 'link_http_1'}}
                        }],
            instances: 1
          )
          spec['azs'] = ['z1']
          spec
        end

        let(:provider2_http) do
          spec = Bosh::Spec::NewDeployments.simple_instance_group(
            name: 'provider2_http_instance_group',
            jobs: [{
                          'name' => 'http_server_with_provides',
                          'properties' => {
                            'listen_port' => 1234,
                            'name_space' => {
                              'prop_a' => '2_some_prop_a'
                            }
                          },
                          'provides' => {'http_endpoint' => {'as' => 'link_http_2'}}
                        }],
            instances: 1
          )
          spec['azs'] = ['z1']
          spec
        end

        let(:consumer_instance_group) do
          spec = Bosh::Spec::NewDeployments.simple_instance_group(
            name: 'consumer_instance_group',
            jobs: [
              {'name' => 'http_proxy_with_requires', 'consumes' => {'proxied_http_endpoint' => {'from' => 'link_http_1'}}},
              {'name' => 'tcp_proxy_with_requires', 'consumes' => {'proxied_http_endpoint' => {'from' => 'link_http_2'}}},
            ],
            instances: 1
          )
          spec['azs'] = ['z1']
          spec
        end

        it 'each job should get the correct link' do
          deploy_simple_manifest(manifest_hash: manifest)

          consumer_instance_group = director.instance('consumer_instance_group', '0')

          http_template = YAML.load(consumer_instance_group.read_job_template('http_proxy_with_requires', 'config/config.yml'))
          tcp_template = YAML.load(consumer_instance_group.read_job_template('tcp_proxy_with_requires', 'config/config.yml'))

          expect(http_template['links']['properties']['listen_port']).to eq(11111)
          expect(http_template['links']['properties']['name_space']['prop_a']).to eq('1_some_prop_a')

          expect(tcp_template['links']['properties']['listen_port']).to eq(1234)
          expect(tcp_template['links']['properties']['name_space']['prop_a']).to eq('2_some_prop_a')

        end
      end

      context 'when one job consumes two links of the same type, where each is provided by the same job on different instance groups' do
        let(:manifest) do
          manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
          manifest['instance_groups'] = [provider_1_db, provider_2_db, consumer_instance_group]
          manifest
        end

        let(:provider_1_db) do
          spec = Bosh::Spec::NewDeployments.simple_instance_group(
            name: 'provider_1_db',
            jobs: [{
                          'name' => 'backup_database',
                          'properties' => {
                            'foo' => 'wow',
                          },
                          'provides' => {'backup_db' => {'as' => 'db_1'}}
                        }],
            instances: 1
          )
          spec['azs'] = ['z1']
          spec
        end

        let(:provider_2_db) do
          spec = Bosh::Spec::NewDeployments.simple_instance_group(
            name: 'provider_2_db',
            jobs: [{
                          'name' => 'backup_database',
                          'properties' => {
                            'foo' => 'omg_no_keyboard',
                          },
                          'provides' => {'backup_db' => {'as' => 'db_2'}}
                        }],
            instances: 1
          )
          spec['azs'] = ['z1']
          spec
        end

        let(:consumer_instance_group) do
          spec = Bosh::Spec::NewDeployments.simple_instance_group(
            name: 'consumer_instance_group',
            jobs: [
              {'name' => 'api_server', 'consumes' => {'db' => {'from' => 'db_1'}, 'backup_db' => {'from' => 'db_2'}}},
            ],
            instances: 1
          )
          spec['azs'] = ['z1']
          spec
        end

        it 'each job should get the correct link' do
          deploy_simple_manifest(manifest_hash: manifest)

          consumer_instance_group = director.instance('consumer_instance_group', '0')

          api_template = YAML.load(consumer_instance_group.read_job_template('api_server', 'config.yml'))

          expect(api_template['databases']['main_properties']).to eq('wow')
          expect(api_template['databases']['backup_properties']).to eq('omg_no_keyboard')

        end
      end

    end

    context 'when provide link is aliased using "as", and the consume link references the old name' do
      let(:manifest) do
        manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
        manifest['instance_groups'] = [api_instance_group_spec, aliased_instance_group_spec]
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
        manifest['instance_groups'] = [api_instance_group_spec, aliased_instance_group_spec]
        manifest
      end

      let(:new_api_instance_group_spec) do
        spec = Bosh::Spec::NewDeployments.simple_instance_group(
            name: 'new_api_job',
            jobs: [{'name' => 'api_server', 'consumes' => links}],
            instances: 1,
            migrated_from: ['name' => 'my_api']
        )
        spec['azs'] = ['z1']
        spec
      end

      let(:new_aliased_instance_group_spec) do
        spec = Bosh::Spec::NewDeployments.simple_instance_group(
            name: 'new_aliased_job',
            jobs: [{'name' => 'backup_database', 'provides' => {'backup_db' => {'as' => 'link_alias'}}}],
            instances: 1,
            migrated_from: ['name' => 'aliased_postgres']
        )
        spec['azs'] = ['z1']
        spec
      end

      it 'deploys migrated_from jobs' do
        deploy_simple_manifest(manifest_hash: manifest)
        manifest['instance_groups'] = [new_api_instance_group_spec, new_aliased_instance_group_spec]
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
        manifest['instance_groups'] = [first_node_instance_group_spec, second_node_instance_group_spec]
        manifest
      end

      let(:first_node_instance_group_spec) do
        Bosh::Spec::NewDeployments.simple_instance_group(
          name: 'first_node',
          jobs: [{'name' => 'node', 'consumes' => first_node_links,'provides' => {'node2' => {'as' => 'alias2'}}}],
          instances: 1,
          static_ips: ['192.168.1.10'],
          azs: ['z1']
        )
      end

      let(:first_node_links) do
        {
          'node1' => {'from' => 'node1'},
          'node2' => {'from' => 'alias2'}
        }
      end

      let(:second_node_instance_group_spec) do
        Bosh::Spec::NewDeployments.simple_instance_group(
          name: 'second_node',
          jobs: [{'name' => 'node', 'consumes' => second_node_links, 'provides' => {'node2' => {'as' => 'alias2'}}}],
          instances: 1,
          static_ips: ['192.168.1.11'],
          azs: ['z1']
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
       manifest['instance_groups'] = [first_deployment_instance_group_spec]
       manifest
     end

     let(:first_deployment_instance_group_spec) do
       spec = Bosh::Spec::NewDeployments.simple_instance_group(
           name: 'first_deployment_node',
           jobs: [{'name' => 'node', 'consumes' => first_deployment_consumed_links, 'provides' => first_deployment_provided_links}],
           instances: 1,
           static_ips: ['192.168.1.10'],
       )
       spec['azs'] = ['z1']
       spec
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

     let(:second_deployment_instance_group_spec) do
       spec = Bosh::Spec::NewDeployments.simple_instance_group(
           name: 'second_deployment_node',
           jobs: [{'name' => 'node', 'consumes' => second_deployment_consumed_links}],
           instances: 1,
           static_ips: ['192.168.1.11']
       )
       spec['azs'] = ['z1']
       spec
     end

     let(:second_manifest) do
       manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
       manifest['name'] = 'second'
       manifest['instance_groups'] = [second_deployment_instance_group_spec]
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

         second_manifest['instance_groups'][0]['instances'] = 2
         second_manifest['instance_groups'][0]['static_ips'] = ['192.168.1.12', '192.168.1.13']
         second_manifest['instance_groups'][0]['networks'][0]['static_ips'] = ['192.168.1.12', '192.168.1.13']

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

           first_deployment_instance_group_spec['networks'] << {
               'name' => 'dynamic-network',
               'default' => ['dns', 'gateway']
           }

           first_deployment_instance_group_spec['networks'] << {
               'name' => 'test'
           }

           upload_cloud_config(cloud_config_hash: cloud_config)
           deploy_simple_manifest(manifest_hash: first_manifest)
           deploy_simple_manifest(manifest_hash: second_manifest)
         end

         it 'should use user specified network from provider job' do
           second_deployment_instance = director.instance('second_deployment_node', '0', deployment_name: 'second')
           second_deployment_template = YAML.load(second_deployment_instance.read_job_template('node', 'config.yml'))

           expect(second_deployment_template['instances']['node1_ips'].first).to match(/.test./)
           expect(second_deployment_template['instances']['node2_ips'].first).to eq('192.168.1.11')
         end

         it 'uses the user specified network for link address FQDN' do
           second_deployment_instance = director.instance('second_deployment_node', '0', deployment_name: 'second')
           second_deployment_template = YAML.load(second_deployment_instance.read_job_template('node', 'config.yml'))

           expect(second_deployment_template['node1_dns']).to eq('q-s0.first-deployment-node.test.first.bosh')
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
           let(:first_deployment_instance_group_spec) do
             spec = Bosh::Spec::NewDeployments.simple_instance_group(
                 name: 'first_deployment_node',
                 jobs: [{'name' => 'node', 'consumes' => first_deployment_consumed_links, 'provides' => first_deployment_provided_links}],
                 instances: 0,
                 static_ips: [],
             )
             spec['azs'] = ['z1']
             spec
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

          mysql_instance_group_spec['networks'] << {
              'name' => 'b'
          }

          postgres_instance_group_spec['networks'] << {
              'name' => 'dynamic-network',
              'default' => ['dns', 'gateway']
          }

          postgres_instance_group_spec['networks'] << {
              'name' => 'b'
          }

          upload_cloud_config(cloud_config_hash: cloud_config)
          deploy_simple_manifest(manifest_hash: manifest)
          should_contain_network_for_job('my_api', 'api_server', /.b./)
        end

        it 'raises an error if network name specified is not one of the networks on the link' do
          manifest['instance_groups'].first['jobs'].first['consumes'] = {
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

          manifest['instance_groups'].first['jobs'].first['consumes'] = {
              'db' => {'from' => 'db', 'network' => 'global_network'},
              'backup_db' => {'from' => 'backup_db', 'network' => 'a'}
          }

          upload_cloud_config(cloud_config_hash: cloud_config)
          expect{deploy_simple_manifest(manifest_hash: manifest)}.to raise_error(RuntimeError, /Can't resolve link 'db' in instance group 'my_api' on job 'api_server' in deployment 'simple' and network 'global_network'./)
        end

        context 'user has duplicate implicit links provided in two jobs over separate networks' do

          let(:mysql_instance_group_spec) do
            spec = Bosh::Spec::NewDeployments.simple_instance_group(
                name: 'mysql',
                jobs: [{'name' => 'database'}],
                instances: 2,
                static_ips: ['192.168.1.10', '192.168.1.11']
            )
            spec['azs'] = ['z1']
            spec['networks'] = [{
                'name' => 'dynamic-network',
                'default' => ['dns', 'gateway']
            }]
            spec
          end

          let(:links) do
            {
                'db' => {'network' => 'dynamic-network'},
                'backup_db' => {'network' => 'a'}
            }
          end

          it 'should choose link from correct network' do
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

          mysql_instance_group_spec = Bosh::Spec::NewDeployments.simple_instance_group(
              name: 'mysql',
              jobs: [{'name' => 'database'}],
              instances: 1,
              static_ips: ['192.168.1.10']
          )
          mysql_instance_group_spec['azs'] = ['z1']

          manifest['instance_groups'] = [api_instance_group_spec, mysql_instance_group_spec, postgres_instance_group_spec]

          deploy_simple_manifest(manifest_hash: manifest)
          should_contain_network_for_job('my_api', 'api_server', /192.168.1.1(0|2)/)
        end

        it 'uses the default network when multiple networks are available from link' do
          postgres_instance_group_spec['networks'] << {
              'name' => 'dynamic-network',
              'default' => ['dns', 'gateway']
          }
          deploy_simple_manifest(manifest_hash: manifest)
          should_contain_network_for_job('my_api', 'api_server', /.dynamic-network./)
        end

      end
    end

    context 'when link provider specifies properties from job spec' do
      let(:mysql_instance_group_spec) do
        spec = Bosh::Spec::NewDeployments.simple_instance_group(
            name: 'mysql',
            jobs: [{'name' => 'database', 'properties' => {'test' => 'test value' }}],
            instances: 2,
            static_ips: ['192.168.1.10', '192.168.1.11']
        )
        spec['azs'] = ['z1']
        spec['networks'] << {
            'name' => 'dynamic-network',
            'default' => ['dns', 'gateway']
        }
        spec
      end

      let(:manifest) do
        manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
        manifest['instance_groups'] = [mysql_instance_group_spec]
        manifest
      end

      it 'allows to be deployed' do
        expect{ deploy_simple_manifest(manifest_hash: manifest) }.to_not raise_error
      end
    end

    context 'when link provider specifies properties not listed in job spec properties' do
      let(:mysql_instance_group_spec) do
        spec = Bosh::Spec::NewDeployments.simple_instance_group(
            name: 'mysql',
            jobs: [{'name' => 'provider_fail'}],
            instances: 2,
            static_ips: ['192.168.1.10', '192.168.1.11']
        )
        spec['azs'] = ['z1']
        spec['networks'] << {
            'name' => 'dynamic-network',
            'default' => ['dns', 'gateway']
        }
        spec
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

      let(:instance_group_consumes_link_spec) do
        spec = Bosh::Spec::NewDeployments.simple_instance_group(
            name: 'deployment-job',
            jobs: [{'name' => 'api_server', 'consumes' => links}],
            instances: 1
        )
        spec['azs'] = ['z1']
        spec
      end

      let(:instance_group_not_consuming_links_spec) do
        spec = Bosh::Spec::NewDeployments.simple_instance_group(
            name: 'deployment-job',
            jobs: [{'name' => 'api_server'}],
            instances: 1
        )
        spec['azs'] = ['z1']
        spec
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
        manifest['instance_groups'] = [instance_group_consumes_link_spec, mysql_instance_group_spec, postgres_instance_group_spec]

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
        manifest['instance_groups'].clear
        manifest['instance_groups'] = [instance_group_not_consuming_links_spec, mysql_instance_group_spec, postgres_instance_group_spec]

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

        current_deployments = bosh_runner.run('deployments', json: true)
        #THERE IS WHITESPACE AT THE END OF THE TABLE. DO NOT REMOVE IT
        expect(table(current_deployments)).to eq([{'name' => 'simple', 'release_s' => 'release_with_minimal_links/0+dev.2', 'stemcell_s' => 'ubuntu-stemcell/1', 'team_s' => '', 'cloud_config' => 'latest'}])


        # ####################################################################
        # 3- Re-deploy release version dev.1 that has jobs with links. It should still work
        manifest['releases'].clear
        manifest['releases'] << {
            'name' => 'release_with_minimal_links',
            'version' => '0+dev.1'
        }
        manifest['instance_groups'] = [instance_group_consumes_link_spec, mysql_instance_group_spec, postgres_instance_group_spec]

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

      context 'when a release job is being used as an addon' do
        let(:instance_group_consumes_link_spec_for_addon) do
          spec = Bosh::Spec::NewDeployments.simple_instance_group(
            name: 'deployment-job',
            jobs: [{'name' => 'api_server', 'consumes' => links, 'release'=> 'simple-link-release'}]
          )
          spec
        end

        let(:deployment_manifest) do
          manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
          manifest['releases'].clear
          manifest['releases'] << {
              'name' => 'simple-link-release',
              'version' => '1.0'
          }

          manifest['instance_groups'] = [ mysql_instance_group_spec, postgres_instance_group_spec]
          manifest['addons'] = [instance_group_consumes_link_spec_for_addon ]
          manifest
        end

        it 'should ONLY use the release version specified in manifest' do
          bosh_runner.run("upload-release #{spec_asset('links_releases/simple-link-release-v1.0.tgz')}")

          _, exit_code_1 = deploy_simple_manifest(manifest_hash: deployment_manifest, return_exit_code: true)
          expect(exit_code_1).to eq(0)

          deployed_instances = director.instances
          mysql_0_instance = director.find_instance(deployed_instances, 'mysql', '0')
          mysql_1_instance = director.find_instance(deployed_instances, 'mysql', '1')
          postgres_0_instance = director.find_instance(deployed_instances, 'postgres', '0')

          mysql_template_1 = YAML.load(mysql_0_instance.read_job_template('api_server', 'config.yml'))
          expect(mysql_template_1['databases']['main'].size).to eq(2)
          expect(mysql_template_1['databases']['main']).to contain_exactly(
               {
                   'id' => "#{mysql_0_instance.id}",
                   'name' => 'mysql',
                   'index' => 0,
                   'address' => anything
               },
               {
                   'id' => "#{mysql_1_instance.id}",
                   'name' => 'mysql',
                   'index' => 1,
                   'address' => anything
               }
           )

          expect(mysql_template_1['databases']['backup']).to contain_exactly(
               {
                   'name' => 'postgres',
                   'az' => 'z1',
                   'index' => 0,
                   'address' => anything
               }
           )

          postgres_template_2 = YAML.load(postgres_0_instance.read_job_template('api_server', 'config.yml'))
          expect(postgres_template_2['databases']['main'].size).to eq(2)
          expect(postgres_template_2['databases']['main']).to contain_exactly(
               {
                   'id' => "#{mysql_0_instance.id}",
                   'name' => 'mysql',
                   'index' => 0,
                   'address' => anything
               },
               {
                   'id' => "#{mysql_1_instance.id}",
                   'name' => 'mysql',
                   'index' => 1,
                   'address' => anything
               }
           )

          expect(postgres_template_2['databases']['backup']).to contain_exactly(
               {
                   'name' => 'postgres',
                   'az' => 'z1',
                   'index' => 0,
                   'address' => anything
               }
           )

          bosh_runner.run("upload-release #{spec_asset('links_releases/simple-link-release-v2.0.tgz')}")

          _, exit_code_2 = deploy_simple_manifest(manifest_hash: deployment_manifest, return_exit_code: true)
          expect(exit_code_2).to eq(0)
        end
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

    context 'when the job consumes only links provided in job specs' do

      context 'when the co-located job has implicit links' do
        let(:provider_instance_group) do
          spec = Bosh::Spec::NewDeployments.simple_instance_group(
              name: 'provider_instance_group',
              jobs: [
                  { 'name' => 'provider' },
                  { 'name' => 'app_server' }
              ],
              instances: 1
          )
          spec['azs'] = ['z1']
          spec
        end
        let(:manifest) do
          manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
          manifest['instance_groups'] = [provider_instance_group]
          manifest
        end
        it 'should NOT be able to reach the links from the co-located job' do
          out, exit_code = deploy_simple_manifest(manifest_hash: manifest, failure_expected: true, return_exit_code: true)
          expect(exit_code).to eq(1)
          expect(out).to include('Error: Unable to render instance groups for deployment. Errors are:')
          expect(out).to include("- Unable to render jobs for instance group 'provider_instance_group'. Errors are:")
          expect(out).to include("- Unable to render templates for job 'app_server'. Errors are:")
          expect(out).to include("- Error filling in template 'config.yml.erb' (line 2: Can't find link 'provider')")
        end
      end

      context 'when the co-located job has explicit links' do
        let(:provider_instance_group) do
          spec = Bosh::Spec::NewDeployments.simple_instance_group(
              name: 'provider_instance_group',
              jobs: [
                  {
                      'name' => 'provider',
                      'provides' => {'provider' => {'as' => 'link_provider'} }
                  },
                  { 'name' => 'app_server' }
              ],
              instances: 1
          )
          spec['azs'] = ['z1']
          spec
        end
        let(:manifest) do
          manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
          manifest['instance_groups'] = [provider_instance_group]
          manifest
        end
        it 'should NOT be able to reach the links from the co-located job' do
          out, exit_code = deploy_simple_manifest(manifest_hash: manifest, failure_expected: true, return_exit_code: true)
          expect(exit_code).to eq(1)
          expect(out).to include('Error: Unable to render instance groups for deployment. Errors are:')
          expect(out).to include("- Unable to render jobs for instance group 'provider_instance_group'. Errors are:")
          expect(out).to include("- Unable to render templates for job 'app_server'. Errors are:")
          expect(out).to include("- Error filling in template 'config.yml.erb' (line 2: Can't find link 'provider')")
        end
      end

      context 'when the co-located job uses links from adjacent jobs' do
        let(:provider_instance_group) do
          spec = Bosh::Spec::NewDeployments.simple_instance_group(
              name: 'provider_instance_group',
              jobs: [
                  { 'name' => 'provider' },
                  { 'name' => 'consumer' },
                  { 'name' => 'app_server' }
              ],
              instances: 1
          )
          spec['azs'] = ['z1']
          spec
        end
        let(:manifest) do
          manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
          manifest['instance_groups'] = [provider_instance_group]
          manifest
        end
        it 'should NOT be able to reach the links from the co-located jobs' do
          out, exit_code = deploy_simple_manifest(manifest_hash: manifest, failure_expected: true, return_exit_code: true)
          expect(exit_code).to eq(1)
          expect(out).to include('Error: Unable to render instance groups for deployment. Errors are:')
          expect(out).to include("- Unable to render jobs for instance group 'provider_instance_group'. Errors are:")
          expect(out).to include("- Unable to render templates for job 'app_server'. Errors are:")
          expect(out).to include("- Error filling in template 'config.yml.erb' (line 2: Can't find link 'provider')")
        end
      end
    end

    context 'when the job consumes multiple links of the same type' do
      let(:provider_instance_group) do
        spec = Bosh::Spec::NewDeployments.simple_instance_group(
            name: 'provider_instance_group',
            jobs: [{
                            'name' => 'database',
                            'provides' => {'db' => {'as' => 'link_db_alias'}},
                            'properties' => {
                                'foo' => 'props_db_bar'
                            }
                        },
                        {
                            'name' => 'backup_database',
                            'provides' => {'backup_db' => {'as' => 'link_backup_db_alias'}},
                            'properties' => {
                                'foo' => 'props_backup_db_bar'
                            }
                        }
            ],
            instances: 1
        )
        spec['azs'] = ['z1']
        spec
      end

      let(:consumer_instance_group) do
        spec = Bosh::Spec::NewDeployments.simple_instance_group(
            name: 'consumer_instance_group',
            jobs: [
                {
                    'name' => 'api_server',
                    'consumes' => {
                        'db' => {'from' => 'link_db_alias'},
                        'backup_db' => {'from' => 'link_backup_db_alias'}
                    }
                },
            ],
            instances: 1
        )
        spec['azs'] = ['z1']
        spec
      end

      let(:manifest) do
        manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
        manifest['instance_groups'] = [provider_instance_group, consumer_instance_group]
        manifest
      end

      it 'should have different content for each link if consumed from different sources' do
        deploy_simple_manifest(manifest_hash: manifest)
        consumer_instance = director.instance('consumer_instance_group', '0')
        template = YAML.load(consumer_instance.read_job_template('api_server', 'config.yml'))

        expect(template['databases']['main_properties']).to eq('props_db_bar')
        expect(template['databases']['backup_properties']).to eq('props_backup_db_bar')
      end
    end

    context 'when consumer and provider has different types' do
      let(:cloud_config) {Bosh::Spec::NewDeployments.simple_cloud_config}

      let(:provider_alias) {'provider_login'}
      let(:provides_definition) do
        {
          'admin' => {
            'as' => provider_alias
          }
        }
      end

      let(:consumes_definition) do
        {
          'login' => {
            'from' => provider_alias
          }
        }
      end

      let(:new_provides_definition) do
        {
          'credentials' => {
            'as' => provider_alias
          }
        }
      end

      def get_provider_instance_group(provides_definition)
        instance_group_spec = Bosh::Spec::NewDeployments.simple_instance_group(
          name: 'provider_ig',
          jobs: [
            {
              'name' => 'provider_job',
              'provides' => provides_definition
            }
          ],
          instances: 2
        )
        instance_group_spec
      end

      let(:consumer_instance_group) do
        instance_group_spec = Bosh::Spec::NewDeployments.simple_instance_group(
          name: 'consumer_ig',
          jobs: [
            {
              'name' => 'consumer_job',
              'consumes' => consumes_definition
            }
          ],
          instances: 1
        )
        instance_group_spec
      end

      let(:releases) do
        [
          {
            'name' => 'changing_job_with_stable_links',
            'version' => 'latest',
          }
        ]
      end

      context 'but the alias is same' do
        let(:manifest) do
          manifest = Bosh::Spec::NewDeployments.minimal_manifest
          manifest['releases'] = releases
          manifest['instance_groups'] = [get_provider_instance_group(provides_definition), consumer_instance_group]
          manifest
        end

        it 'should fail to create the link' do
          bosh_runner.run("upload-release #{spec_asset('changing-release-0+dev.3.tgz')}")
          output = deploy_simple_manifest(manifest_hash: manifest, failure_expected: true)
          expect(output).to include(%Q{Error: Cannot resolve link path 'minimal.provider_ig.provider_job.provider_login' required for link 'login' in instance group 'consumer_ig' on job 'consumer_job'})
        end

        context 'and the link is shared from another deployment' do
          let(:provider_manifest) do
            manifest = Bosh::Spec::NewDeployments.minimal_manifest
            manifest['name'] = 'provider_deployment'
            manifest['releases'] = releases
            manifest['instance_groups'] = [get_provider_instance_group(provides_definition)]
            manifest
          end

          let(:consumer_manifest) do
            manifest = Bosh::Spec::NewDeployments.minimal_manifest
            manifest['name'] = 'consumer_deployment'
            manifest['releases'] = releases
            manifest['instance_groups'] = [consumer_instance_group]
            manifest
          end

          let(:provides_definition) do
            {
              'admin' => {
                'shared' => true,
                'as' => provider_alias
              }
            }
          end

          let(:consumes_definition) do
            {
              'login' => {
                'deployment' => provider_manifest['name'],
                'from' => provider_alias
              }
            }
          end

          before do
            bosh_runner.run("upload-release #{spec_asset('changing-release-0+dev.3.tgz')}")
            deploy_simple_manifest(manifest_hash: provider_manifest)
          end

          it 'should fail to create the link' do
            output = deploy_simple_manifest(manifest_hash: consumer_manifest, failure_expected: true)
            expect(output).to include(%Q{Error: Cannot resolve link path 'provider_deployment.provider_ig.provider_job.provider_login' required for link 'login' in instance group 'consumer_ig' on job 'consumer_job'})
          end
        end
      end
    end
  end

  context 'when addon job requires link' do

    let(:mysql_instance_group_spec) do
      spec = Bosh::Spec::NewDeployments.simple_instance_group(
          name: 'mysql',
          jobs: [{'name' => 'database'}],
          instances: 1,
          static_ips: ['192.168.1.10']
      )
      spec['azs'] = ['z1']
      spec['networks'] << {
          'name' => 'dynamic-network',
          'default' => ['dns', 'gateway']
      }
      spec
    end

    before do
      runtime_config_file = yaml_file('runtime_config.yml', Bosh::Spec::Deployments.runtime_config_with_links)
      bosh_runner.run("update-runtime-config #{runtime_config_file.path}")
    end

    it 'should resolve links for addons' do
      manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
      manifest['releases'][0]['version'] = '0+dev.1'
      manifest['instance_groups'] = [mysql_instance_group_spec]

      deploy_simple_manifest(manifest_hash: manifest)

      my_sql_instance = director.instance('mysql', '0', deployment_name: 'simple')
      template = YAML.load(my_sql_instance.read_job_template('addon', 'config.yml'))

      template['databases'].each do |_, database|
        database.each do |instance|
          expect(instance['address']).to match(/.dynamic-network./)
        end
      end
    end
  end

  context 'checking link properties' do
    let(:instance_group_with_nil_properties) do
      spec = Bosh::Spec::NewDeployments.simple_instance_group(
          name: 'property_job',
          jobs: [{'name' => 'provider', 'properties' => {'a' => 'deployment_a'}}, {'name' => 'consumer'}],
          instances: 1,
          static_ips: ['192.168.1.10'],
          properties: {}
      )
      spec['azs'] = ['z1']
      spec['networks'] << {
          'name' => 'dynamic-network',
          'default' => ['dns', 'gateway']
      }
      spec
    end

    let (:instance_group_with_manual_consumes_link) do
      spec = Bosh::Spec::NewDeployments.simple_instance_group(
          name: 'property_job',
          jobs: [{'name' => 'consumer', 'consumes' => {'provider' => {'properties' => {'a' => 2, 'b' => 3, 'c' => 4, 'nested' => {'one' => 'three', 'two' => 'four'}}, 'instances' => [{'name' => 'external_db', 'address' => '192.168.15.4'}], 'networks' => {'a' => 2, 'b' => 3}}}}],
          instances: 1,
          static_ips: ['192.168.1.10'],
          properties: {}
      )
      spec['azs'] = ['z1']
      spec['networks'] << {
          'name' => 'dynamic-network',
          'default' => ['dns', 'gateway']
      }
      spec
    end

    let(:instance_group_with_link_properties_not_defined_in_release_properties) do
      spec = Bosh::Spec::NewDeployments.simple_instance_group(
          name: 'jobby',
          jobs: [{'name' => 'provider', 'properties' => {'doesntExist' => 'someValue'}}],
          instances: 1,
          static_ips: ['192.168.1.10'],
          properties: {}
      )
      spec['azs'] = ['z1']
      spec['networks'] << {
          'name' => 'dynamic-network',
          'default' => ['dns', 'gateway']
      }
      spec
    end

    it 'should not raise an error when consuming links without properties' do
      manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
      manifest['releases'][0]['version'] = '0+dev.1'
      manifest['instance_groups'] = [instance_group_with_nil_properties]

      out, exit_code = deploy_simple_manifest(manifest_hash: manifest, return_exit_code: true)

      expect(exit_code).to eq(0)
    end

    it 'should not raise an error when a deployment template property is not defined in the release properties' do
      manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
      manifest['releases'][0]['version'] = '0+dev.1'
      manifest['instance_groups'] = [instance_group_with_link_properties_not_defined_in_release_properties]

      out, exit_code = deploy_simple_manifest(manifest_hash: manifest,  return_exit_code: true)

      expect(exit_code).to eq(0)
    end

    it 'should be able to resolve a manual configuration in a consumes link' do
      manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
      manifest['instance_groups'] = [instance_group_with_manual_consumes_link]

      out, exit_code = deploy_simple_manifest(manifest_hash: manifest, return_exit_code: true)
      expect(exit_code).to eq(0)

      link_instance = director.instance('property_job', '0')

      template = YAML.load(link_instance.read_job_template('consumer', 'config.yml'))

      expect(template['a']).to eq(2)
      expect(template['b']).to eq(3)
      expect(template['c']).to eq(4)
      expect(template['nested']['one']).to eq('three')
      expect(template['nested']['two']).to eq('four')
    end

    it 'should only have one consumer and no providers' do
      manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
      manifest['instance_groups'] = [instance_group_with_manual_consumes_link]

      deploy_simple_manifest(manifest_hash: manifest, return_exit_code: true)

      response = send_director_api_request("/link_providers", "deployment=#{manifest['name']}", 'GET')
      expect(response).not_to eq(nil)
      response_body = JSON.parse(response.read_body)
      expect(response_body.count).to eq(0)

      response = send_director_api_request("/link_consumers", "deployment=#{manifest['name']}", 'GET')
      expect(response).not_to eq(nil)
      response_body = JSON.parse(response.read_body)
      expect(response_body.count).to eq(1)
    end
  end

  context 'when link is not satisfied in deployment' do
    let(:bad_properties_instance_group_spec) do
      spec = Bosh::Spec::NewDeployments.simple_instance_group(
          name: 'api_server_with_bad_link_types',
          jobs: [{'name' => 'api_server_with_bad_link_types'}],
          instances: 1,
          static_ips: ['192.168.1.10']
      )
      spec['azs'] = ['z1']
      spec['networks'] << {
          'name' => 'dynamic-network',
          'default' => ['dns', 'gateway']
      }
      spec
    end

    it 'should show all errors' do
      manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
      manifest['releases'][0]['version'] = '0+dev.1'
      manifest['instance_groups'] = [bad_properties_instance_group_spec]

      out, exit_code = deploy_simple_manifest(manifest_hash: manifest, failure_expected: true, return_exit_code: true)

      expect(exit_code).not_to eq(0)
      expect(out).to include('Error: Unable to process links for deployment. Errors are:')
      expect(out).to include("- Can't find link with type 'bad_link' for job 'api_server_with_bad_link_types' in deployment 'simple'")
      expect(out).to include("- Can't find link with type 'bad_link_2' for job 'api_server_with_bad_link_types' in deployment 'simple'")
      expect(out).to include("- Can't find link with type 'bad_link_3' for job 'api_server_with_bad_link_types' in deployment 'simple'")
    end
  end
end
