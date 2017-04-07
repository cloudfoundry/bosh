require_relative '../../spec_helper'

describe 'using director with config server and deployments having links', type: :integration do
  with_reset_sandbox_before_each(config_server_enabled: true, user_authentication: 'uaa', uaa_encryption: 'asymmetric')

  def upload_links_release
    FileUtils.cp_r(LINKS_RELEASE_TEMPLATE, ClientSandbox.links_release_dir, :preserve => true)
    bosh_runner.run_in_dir('create-release --force', ClientSandbox.links_release_dir, include_credentials: false,  env: client_env)
    bosh_runner.run_in_dir('upload-release', ClientSandbox.links_release_dir, include_credentials: false,  env: client_env)
  end

  def prepend_namespace(key)
    "/#{director_name}/#{deployment_name}/#{key}"
  end

  let(:director_name) { current_sandbox.director_name }
  let(:client_env) { {'BOSH_CLIENT' => 'test', 'BOSH_CLIENT_SECRET' => 'secret', 'BOSH_CA_CERT' => "#{current_sandbox.certificate_path}"} }
  let(:config_server_helper) { Bosh::Spec::ConfigServerHelper.new(current_sandbox, logger)}

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

  let(:job_properties) do
    {
      'gargamel' => {
        'color' => '((my_placeholder))'
      }
    }
  end

  let(:provider_job_name) { 'http_server_with_provides' }
  let(:my_instance_group) do
    job_spec = Bosh::Spec::Deployments.simple_job(
      name: 'my_instance_group',
      templates: [
        {
          'name' => provider_job_name,
          'properties' => {'name_space' => {'fibonacci' => '((fibonacci_placeholder))'}},
        },
        {'name' => 'http_proxy_with_requires'},
      ],
      instances: 1
    )
    job_spec['azs'] = ['z1']
    job_spec
  end
  let(:manifest) do
    manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
    manifest['jobs'] = [my_instance_group]
    manifest['properties'] = {'listen_port' => 9999}
    manifest
  end
  let(:deployment_name) { manifest['name'] }

  before do
    upload_links_release
    upload_stemcell(include_credentials: false,  env: client_env)

    upload_cloud_config(cloud_config_hash: cloud_config, include_credentials: false,  env: client_env)
  end

  context 'when having intra-deployment links' do
    it 'replaces the placeholder values of properties consumed through links' do
      config_server_helper.put_value(prepend_namespace('fibonacci_placeholder'), 'fibonacci_value')
      deploy_simple_manifest(manifest_hash: manifest, include_credentials: false,  env: client_env)

      link_instance = director.instance('my_instance_group', '0', deployment_name: 'simple', include_credentials: false,  env: client_env)
      template = YAML.load(link_instance.read_job_template('http_proxy_with_requires', 'config/config.yml'))
      expect(template['links']['properties']['fibonacci']).to eq('fibonacci_value')

      config_server_helper.put_value(prepend_namespace('fibonacci_placeholder'), 'recursion is the best')

      deploy_simple_manifest(manifest_hash: manifest, include_credentials: false,  env: client_env)

      link_instance = director.instance('my_instance_group', '0', deployment_name: 'simple', include_credentials: false,  env: client_env)
      template = YAML.load(link_instance.read_job_template('http_proxy_with_requires', 'config/config.yml'))
      expect(template['links']['properties']['fibonacci']).to eq('recursion is the best')
    end

    it 'does not log interpolated properties in deploy output and debug logs' do
      skip("#130127863")

      config_server_helper.put_value(prepend_namespace('fibonacci_placeholder'), 'fibonacci_value')
      deploy_output = deploy_simple_manifest(manifest_hash: manifest, include_credentials: false,  env: client_env)
      debug_output = bosh_runner.run('task last --debug', no_login: true, include_credentials: false,  env: client_env)

      expect(deploy_output).to_not include('fibonacci_value')
      expect(debug_output).to_not include('fibonacci_value')
    end

    context "when the consumer's job render fails on a subsequent deploy" do
      let(:consumer_instance_group) do
        Bosh::Spec::Deployments.simple_job(
          name: 'consumer_instance_group',
          templates: [
            {
              'name' => 'http_proxy_with_requires',
            },
          ],
          instances: 2,
          azs: ['z1']
        )
      end

      let(:provider_instance_group) do
        Bosh::Spec::Deployments.simple_job(
          name: 'provider_instance_group',
          templates: [
            {
              'name' => provider_job_name,
              'properties' => {'name_space' => {'fibonacci' => '((fibonacci_placeholder))'}},
            },
          ],
          instances: 1,
          azs: ['z1']
        )
      end
      let(:manifest) do
        manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
        manifest['jobs'] = [provider_instance_group, consumer_instance_group]
        manifest
      end

      it "should preserve variable id for jobs that haven't be updated" do
        config_server_helper.put_value(prepend_namespace('fibonacci_placeholder'), 'leonardo')

        deploy_simple_manifest(manifest_hash: manifest, include_credentials: false,  env: client_env)

        config_server_helper.put_value(prepend_namespace('fibonacci_placeholder'), 'Pisa')

        consumer_instance_group['properties'][ 'http_proxy_with_requires'] = {
          'fail_instance_index' => 0,
          'fail_on_job_start' => true,
        }

        _, exit_code = deploy_simple_manifest(manifest_hash: manifest, include_credentials: false,  env: client_env,
                                              failure_expected: true, return_exit_code: true,)

        expect(exit_code).to_not eq(0)

        bosh_runner.run('recreate consumer_instance_group', deployment_name: manifest['name'], include_credentials: false, env: client_env)

        link_instance = director.instance('consumer_instance_group', '0', deployment_name: 'simple', include_credentials: false,  env: client_env)
        template = YAML.load(link_instance.read_job_template('http_proxy_with_requires', 'config/config.yml'))
        expect(template['links']['properties']['fibonacci']).to eq('Pisa')

        link_instance = director.instance('consumer_instance_group', '1', deployment_name: 'simple', include_credentials: false,  env: client_env)
        template = YAML.load(link_instance.read_job_template('http_proxy_with_requires', 'config/config.yml'))
        expect(template['links']['properties']['fibonacci']).to eq('leonardo')
      end
    end

    context 'when provider job has properties with type password and values are generated' do
      let(:provider_job_name) { 'http_endpoint_provider_with_property_types' }

      it 'replaces the placeholder values of properties consumed through links' do
        deploy_simple_manifest(manifest_hash: manifest, include_credentials: false,  env: client_env)

        link_instance = director.instance('my_instance_group', '0', deployment_name: 'simple', include_credentials: false,  env: client_env)
        template = YAML.load(link_instance.read_job_template('http_proxy_with_requires', 'config/config.yml'))
        expect(template['links']['properties']['fibonacci']).to eq(config_server_helper.get_value(prepend_namespace('fibonacci_placeholder')))
      end
    end

    context 'when manual links are involved' do
      let (:job_with_manual_consumes_link) do
        job_spec = Bosh::Spec::Deployments.simple_job(
          name: 'property_job',
          templates: [{
                        'name' => 'consumer',
                        'consumes' => {
                          'provider' => {
                            'properties' => {'a' => '((a_placeholder))', 'b' => '((b_placeholder))', 'c' => '((c_placeholder))'},
                            'instances' => [{'name' => 'external_db', 'address' => '192.168.15.4'}],
                            'networks' => {'network_1' => 2, 'network_2' => 3}
                          }
                        }
                      }],
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

      let(:deployment_name) {manifest['name']}

      before do
        config_server_helper.put_value(prepend_namespace('a_placeholder'), 'a_value')
        config_server_helper.put_value(prepend_namespace('b_placeholder'), 'b_value')
        config_server_helper.put_value(prepend_namespace('c_placeholder'), 'c_value')

        manifest['jobs'] = [job_with_manual_consumes_link]
      end

      it 'resolves the properties defined inside the links section of the deployment manifest' do
        deploy_simple_manifest(manifest_hash: manifest, include_credentials: false,  env: client_env)

        link_instance = director.instance('property_job', '0', deployment_name: 'simple', include_credentials: false,  env: client_env)

        template = YAML.load(link_instance.read_job_template('consumer', 'config.yml'))

        expect(template['a']).to eq('a_value')
        expect(template['b']).to eq('b_value')
        expect(template['c']).to eq('c_value')
      end

      it 'does not log interpolated properties in deploy output and debug logs' do
        skip("#130127863")

        deploy_output = deploy_simple_manifest(manifest_hash: manifest, include_credentials: false,  env: client_env)
        debug_output = bosh_runner.run('task last --debug', no_login: true, include_credentials: false,  env: client_env)

        expect(deploy_output).to_not include('a_value')
        expect(deploy_output).to_not include('b_value')
        expect(deploy_output).to_not include('c_value')

        expect(debug_output).to_not include('a_value')
        expect(debug_output).to_not include('b_value')
        expect(debug_output).to_not include('c_value')
      end
    end
  end

  context 'when having cross deployment links' do
    let(:provider_manifest) do
      manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
      manifest['name'] = 'provider_deployment_name'
      manifest['jobs'] = [provider_deployment_job_spec]
      manifest
    end

    let(:provider_deployment_job_spec) do
      job_spec = Bosh::Spec::Deployments.simple_job(
        name: 'provider_deployment_node',
        templates: [
          {
            'name' => provider_job_name,
            'properties' => {
              'listen_port' => 15672,
              'name_space' => {
                'fibonacci' => '((fibonacci_placeholder))'
              }
            },
            'provides' => {
              'http_endpoint' => {
                'as' => 'vroom',
                'shared' => true
              }
            }
          }
        ],
        instances: 1,
        static_ips: ['192.168.1.10'],
      )
      job_spec['azs'] = ['z1']
      job_spec
    end

    let(:consumer_manifest) do
      manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
      manifest['name'] = 'consumer_deployment_name'
      manifest['jobs'] = [consumer_deployment_job_spec]
      manifest
    end

    let(:consumer_deployment_job_spec) do
      job_spec = Bosh::Spec::Deployments.simple_job(
        name: 'consumer_deployment_node',
        templates: [
          {
            'name' => 'http_proxy_with_requires',
            'release' => 'bosh-release',
            'consumes' => {
              'proxied_http_endpoint' => {
                'from' => 'vroom',
                'deployment' => 'provider_deployment_name'
              }
            }
          }
        ],
        instances: 1,
        static_ips: ['192.168.1.11']
      )
      job_spec['azs'] = ['z1']
      job_spec
    end

    let(:deployment_name) {provider_manifest['name']}

    context 'given a successful provider deployment' do
      before do
        config_server_helper.put_value(prepend_namespace('fibonacci_placeholder'), 'fibonacci_value_1')
        deploy_simple_manifest(no_login: true, manifest_hash: provider_manifest, include_credentials: false,  env: client_env)
      end

      context 'when deploying the consumer deployment' do
        before do
          deploy_simple_manifest(no_login: true, manifest_hash: consumer_manifest, include_credentials: false,  env: client_env)
        end

        it 'should successfully use the shared links' do
          link_instance = director.instance('consumer_deployment_node', '0', {:deployment_name => 'consumer_deployment_name', :env => client_env, include_credentials: false})
          template = YAML.load(link_instance.read_job_template('http_proxy_with_requires', 'config/config.yml'))
          expect(template['links']['properties']['fibonacci']).to eq('fibonacci_value_1')
        end

        context 'when updating config server values' do
          before do
            config_server_helper.put_value(prepend_namespace('fibonacci_placeholder'), 'fibonacci_value_2')
          end

          context 'when re-deploying the provider deployment' do
            before do
              deploy_simple_manifest(no_login: true, manifest_hash: provider_manifest, include_credentials: false,  env: client_env)
            end

            context 'and then updating config server values one more time' do
              before do
                config_server_helper.put_value(prepend_namespace('fibonacci_placeholder'), 'fibonacci_value_3')
              end

              context 'when re-deploying the consumer deployment' do
                before do
                  deploy_simple_manifest(no_login: true, manifest_hash: consumer_manifest, include_credentials: false,  env: client_env)
                end

                it 'the consumer deployment picks up the variables of the last successful provider deployment' do
                  link_instance = director.instance('consumer_deployment_node', '0', {:deployment_name => 'consumer_deployment_name', :env => client_env, include_credentials: false})
                  template = YAML.load(link_instance.read_job_template('http_proxy_with_requires', 'config/config.yml'))
                  expect(template['links']['properties']['fibonacci']).to eq('fibonacci_value_2')
                end
              end

              context 'when recreating the consumer deployment VMs' do
                before do
                  bosh_runner.run('recreate', deployment_name: consumer_manifest['name'], no_login: true, include_credentials: false,  env: client_env)
                end

                it 'the consumer deployment is still rendered with the variable versions it was deployed with' do
                  link_instance = director.instance('consumer_deployment_node', '0', {:deployment_name => 'consumer_deployment_name', :env => client_env, include_credentials: false})
                  template = YAML.load(link_instance.read_job_template('http_proxy_with_requires', 'config/config.yml'))
                  expect(template['links']['properties']['fibonacci']).to eq('fibonacci_value_1')
                end
              end

              context 'when resurrector kicks in to recreate an unresponsive consumer VM' do
                with_reset_hm_before_each

                it 'the consumer deployment VM is still rendered with the variable versions it was originally deployed with' do
                  link_instance = director.instance('consumer_deployment_node', '0', {:deployment_name => 'consumer_deployment_name', :env => client_env, include_credentials: false})
                  director.kill_vm_and_wait_for_resurrection(link_instance, deployment_name: 'consumer_deployment_name', include_credentials: false, env: client_env)

                  resurrected_link_instance = director.instance('consumer_deployment_node', '0', {:deployment_name => 'consumer_deployment_name', :env => client_env, include_credentials: false})
                  template = YAML.load(resurrected_link_instance.read_job_template('http_proxy_with_requires', 'config/config.yml'))
                  expect(template['links']['properties']['fibonacci']).to eq('fibonacci_value_1')
                  expect(resurrected_link_instance.vm_cid).to_not eq(link_instance.vm_cid)
                end
              end
            end
          end
        end
      end
    end

    context 'given a successful provider deployment containing generated job properties with type password' do
      let(:provider_job_name) { 'http_endpoint_provider_with_property_types' }

      before do
        deploy_simple_manifest(no_login: true, manifest_hash: provider_manifest, include_credentials: false,  env: client_env)
      end

      it 'should successfully use the generated shared link properties' do
        generated_value = config_server_helper.get_value(prepend_namespace('fibonacci_placeholder'))
        deploy_simple_manifest(no_login: true, manifest_hash: consumer_manifest, include_credentials: false,  env: client_env)

        link_instance = director.instance('consumer_deployment_node', '0', {:deployment_name => 'consumer_deployment_name', :env => client_env, include_credentials: false})
        template = YAML.load(link_instance.read_job_template('http_proxy_with_requires', 'config/config.yml'))
        expect(template['links']['properties']['fibonacci']).to eq(generated_value)
      end
    end

    context 'when using runtime config' do
      let(:runtime_config) do
        {
          'releases' => [{'name' => 'bosh-release', 'version' => '0.1-dev'}],
          'addons' => [
            {
              'name' => 'addon_job',
              'jobs' => [
                'name' => 'http_proxy_with_requires',
                'release' => 'bosh-release',
                'consumes' => {
                  'proxied_http_endpoint' => {
                    'from' => 'vroom',
                    'deployment' => 'provider_deployment_name'
                  }
                }
              ]

            }
          ]
        }
      end

      let(:consumer_deployment_job_spec) do
        job_spec = Bosh::Spec::Deployments.simple_job(
          name: 'consumer_deployment_node',
          templates: [
            {
              'name' => 'provider',
              'release' => 'bosh-release'
            }
          ],
          instances: 1,
          static_ips: ['192.168.1.11']
        )
        job_spec['azs'] = ['z1']
        job_spec
      end

      before do
        config_server_helper.put_value(prepend_namespace('fibonacci_placeholder'), 'bosh_is_nice')
        deploy_simple_manifest(no_login: true, manifest_hash: provider_manifest, include_credentials: false,  env: client_env)
      end

      it 'should successfully use shared link from provider deployment' do
        expect(upload_runtime_config(runtime_config_hash: runtime_config, include_credentials: false,  env: client_env)).to include('Succeeded')
        deploy_simple_manifest(no_login: true, manifest_hash: consumer_manifest, include_credentials: false,  env: client_env)

        link_instance = director.instance('consumer_deployment_node', '0', {:deployment_name => 'consumer_deployment_name', :env => client_env, include_credentials: false})
        template = YAML.load(link_instance.read_job_template('http_proxy_with_requires', 'config/config.yml'))
        expect(template['links']['properties']['fibonacci']).to eq('bosh_is_nice')
      end
    end

    context 'handling of absolute variables being defined in the consumer deployment and provider deployment' do
      context 'given provider deployment providing a property with value as an absolute variable' do
        before do
          provider_deployment_job_spec['templates'][0]['properties']['name_space']['fibonacci'] = '((/fibonacci_variable))'
          config_server_helper.put_value('/fibonacci_variable', 'fibonacci_value_1')
          deploy_simple_manifest(no_login: true, manifest_hash: provider_manifest, include_credentials: false,  env: client_env)
        end

        context 'given a consumer deployment which defines a property value with same absolute variable' do
          before do
            consumer_deployment_job_spec['templates'][0]['properties'] = {
              'http_proxy_with_requires' => {
                'listen_port' => '((/fibonacci_variable))'
              }
            }
          end

          it 'versions the 2 variables separately' do
            deploy_simple_manifest(no_login: true, manifest_hash: consumer_manifest, include_credentials: false,  env: client_env)
            link_instance = director.instance('consumer_deployment_node', '0', {:deployment_name => 'consumer_deployment_name', :env => client_env, include_credentials: false})
            template = YAML.load(link_instance.read_job_template('http_proxy_with_requires', 'config/config.yml'))
            expect(template['links']['properties']['fibonacci']).to eq('fibonacci_value_1')
            expect(template['property_listen_port']).to eq('fibonacci_value_1')

            config_server_helper.put_value('/fibonacci_variable', 'fibonacci_value_2')
            deploy_simple_manifest(no_login: true, manifest_hash: consumer_manifest, include_credentials: false,  env: client_env)

            link_instance = director.instance('consumer_deployment_node', '0', {:deployment_name => 'consumer_deployment_name', :env => client_env, include_credentials: false})
            template = YAML.load(link_instance.read_job_template('http_proxy_with_requires', 'config/config.yml'))
            expect(template['links']['properties']['fibonacci']).to eq('fibonacci_value_1')
            expect(template['property_listen_port']).to eq('fibonacci_value_2')
          end

          context 'when recreating the consumer deployment' do
            it 'should use the variables it was created with' do
              config_server_helper.put_value('/fibonacci_variable', 'fibonacci_value_2')
              deploy_simple_manifest(no_login: true, manifest_hash: consumer_manifest, include_credentials: false,  env: client_env)

              config_server_helper.put_value('/fibonacci_variable', 'fibonacci_value_3')
              deploy_simple_manifest(no_login: true, manifest_hash: provider_manifest, include_credentials: false,  env: client_env)

              bosh_runner.run('recreate consumer_instance_group', deployment_name: consumer_manifest['name'], include_credentials: false, env: client_env)
              link_instance = director.instance('consumer_deployment_node', '0', {:deployment_name => 'consumer_deployment_name', :env => client_env, include_credentials: false})
              template = YAML.load(link_instance.read_job_template('http_proxy_with_requires', 'config/config.yml'))
              expect(template['links']['properties']['fibonacci']).to eq('fibonacci_value_1')
              expect(template['property_listen_port']).to eq('fibonacci_value_2')
            end
          end
        end
      end
    end
  end
end
