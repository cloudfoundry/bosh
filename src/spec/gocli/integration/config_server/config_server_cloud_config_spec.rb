require_relative '../../spec_helper'

describe 'using director with config server', type: :integration do
  with_reset_sandbox_before_each(config_server_enabled: true, user_authentication: 'uaa', uaa_encryption: 'asymmetric')
  let(:manifest_hash) do
    {
        'name' => 'simple',
        'director_uuid' => 'deadbeef',
        'releases' => [{'name' => 'bosh-release', 'version' => '0.1-dev'}],
        'update' => {
            'canaries' => 2,
            'canary_watch_time' => 4000,
            'max_in_flight' => 1,
            'update_watch_time' => 20
        },
        'instance_groups' => [{
            'name' => 'our_instance_group',
            'templates' => [{
                'name' => 'job_1_with_many_properties',
                'properties' => {
                    'gargamel' => {
                        'color' => 'pitch black'
                    }
                }
            }],
            'instances' => 1,
            'networks' => [{'name' => 'private'}],
            'properties' => {},
            'vm_type' => 'medium',
            'persistent_disk_type' => 'large',
            'azs' => ['z1'],
            'stemcell' => 'default'
        }],
        'stemcells' => [{'alias' => 'default', 'os' => 'toronto-os', 'version' => '1'}]
    }
  end

  let(:client_env) { {'BOSH_CLIENT' => 'test', 'BOSH_CLIENT_SECRET' => 'secret', 'BOSH_CA_CERT' => "#{current_sandbox.certificate_path}"} }
  let(:config_server_helper) { Bosh::Spec::ConfigServerHelper.new(current_sandbox, logger)}

  let(:log_options) { { include_credentials: false, env: client_env } }

  def bosh_run_cck_with_resolution(num_errors, option=1, env={})
    env.each do |key, value|
      ENV[key] = value
    end

    output = ''
    bosh_runner.run_interactively('cck', deployment_name: 'simple', no_login: true, include_credentials: false) do |runner|
      (1..num_errors).each do
        expect(runner).to have_output 'Skip for now'

        runner.send_keys option.to_s
      end

      expect(runner).to have_output 'Continue?'
      runner.send_keys 'y'

      expect(runner).to have_output 'Succeeded'
      output = runner.output
    end
    output
  end


  context 'cloud config contains placeholders' do
    let(:cloud_config) { Bosh::Spec::Deployments.cloud_config_with_placeholders }

    context 'all placeholders are set in config server' do
      before do
        config_server_helper.put_value('/z1_cloud_properties', {'availability_zone' => 'us-east-1a'})
        config_server_helper.put_value('/z2_cloud_properties', {'availability_zone' => 'us-east-1b'})
        config_server_helper.put_value('/ephemeral_disk_placeholder', {'size' => '3000', 'type' => 'gp2'})
        config_server_helper.put_value('/disk_types_placeholder', [
            {
                'name' => 'small',
                'disk_size' => 3000,
                'cloud_properties' => {'type' => 'gp2'}
            }, {
                'name' => 'large',
                'disk_size' => 50_000,
                'cloud_properties' => {'type' => 'gp2'}
            }
        ])
        config_server_helper.put_value('/subnets_placeholder', [
            {
                'range' => '10.10.0.0/24',
                'gateway' => '10.10.0.1',
                'az' => 'z1',
                'static' => ['10.10.0.62'],
                'dns' => ['10.10.0.2'],
                'cloud_properties' => {'subnet' => 'subnet-f2744a86'}
            }, {
                'range' => '10.10.64.0/24',
                'gateway' => '10.10.64.1',
                'az' => 'z2',
                'static' => ['10.10.64.121', '10.10.64.122'],
                'dns' => ['10.10.0.2'],
                'cloud_properties' => {'subnet' => 'subnet-eb8bd3ad'}
            }
        ])
        config_server_helper.put_value('/workers_placeholder', 5)
      end

      it 'uses the interpolated values for a successful deploy' do
        deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false, env: client_env)

        create_vm_invocations = current_sandbox.cpi.invocations_for_method('create_vm')
        expect(create_vm_invocations.last.inputs['cloud_properties']).to eq({'availability_zone'=>'us-east-1a', 'ephemeral_disk'=>{'size'=>'3000','type'=>'gp2'}, 'instance_type'=>'m3.medium'})

        create_disk_invocations = current_sandbox.cpi.invocations_for_method('create_disk')
        expect(create_disk_invocations.last.inputs['size']).to eq(50_000)
        expect(create_disk_invocations.last.inputs['cloud_properties']).to eq({'type' => 'gp2'})
      end

      context 'after a successful deployment' do
        before do
          deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, return_exit_code: true, include_credentials: false, env: client_env)
        end

        context 'variable values were changed' do
          before do
            config_server_helper.put_value('/z1_cloud_properties', {'availability_zone' => 'us-mid-west'})
            config_server_helper.put_value('/disk_types_placeholder', [{'name' => 'large', 'disk_size' => 100_000, 'cloud_properties' => {'type' => 'gp1'}}])
          end

          context 'deployment has unresponsive agents' do
            before {
              current_sandbox.cpi.kill_agents
            }

            it 'should use old variable value during CCK - recreate VM' do
              pre_kill_invocations_size = current_sandbox.cpi.invocations.size

              recreate_vm = 3
              bosh_run_cck_with_resolution(1, recreate_vm, client_env)

              invocations = current_sandbox.cpi.invocations.drop(pre_kill_invocations_size)
              create_vm_invocation = invocations.select { |invocation| invocation.method_name == 'create_vm' }.last
              expect(create_vm_invocation.inputs['cloud_properties']).to eq({'availability_zone'=>'us-east-1a', 'ephemeral_disk'=>{'size'=>'3000','type'=>'gp2'}, 'instance_type'=>'m3.medium'})
            end
          end

          it 'should use old variable value during hard stop, start' do
            instance = director.instance('our_instance_group', '0', deployment_name: 'simple', include_credentials: false, env: client_env)

            bosh_runner.run("stop --hard #{instance.job_name}/#{instance.id}", deployment_name: 'simple', no_login: true, include_credentials: false, env: client_env)
            pre_start_invocations_size = current_sandbox.cpi.invocations.size

            bosh_runner.run("start #{instance.job_name}/#{instance.id}", deployment_name: 'simple', no_login: true, include_credentials: false, env: client_env)
            invocations = current_sandbox.cpi.invocations.drop(pre_start_invocations_size)

            create_vm_invocation = invocations.select { |invocation| invocation.method_name == 'create_vm' }.last
            expect(create_vm_invocation.inputs['cloud_properties']).to eq({'availability_zone'=>'us-east-1a', 'ephemeral_disk'=>{'size'=>'3000','type'=>'gp2'}, 'instance_type'=>'m3.medium'})
          end

          it 'should use the new variable values on redeploy' do
            pre_second_deploy_invocations_size = current_sandbox.cpi.invocations.size
            deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, return_exit_code: true, include_credentials: false, env: client_env)
            invocations = current_sandbox.cpi.invocations.drop(pre_second_deploy_invocations_size)

            create_vm_invocation = invocations.select { |invocation| invocation.method_name == 'create_vm' }.last
            expect(create_vm_invocation.inputs['cloud_properties']).to eq({'availability_zone'=>'us-mid-west', 'ephemeral_disk'=>{'size'=>'3000','type'=>'gp2'}, 'instance_type'=>'m3.medium'})

            create_disk_invocation = invocations.select { |invocation| invocation.method_name == 'create_disk' }.last
            expect(create_disk_invocation.inputs['cloud_properties']).to eq({'type' => 'gp1'})
            expect(create_disk_invocation.inputs['size']).to eq(100_000)
          end
        end

        context 'only leaf-cloud-property variable values were changed' do
          before do
            config_server_helper.put_value('/ephemeral_disk_placeholder',{'size' => '2000', 'type' => 'gp1'})
          end

          it 'should recreate the VM on redeploy' do
            old_instance = director.instance('our_instance_group', '0', deployment_name: 'simple', include_credentials: false, env: client_env)
            deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, return_exit_code: true, include_credentials: false, env: client_env)
            new_instance = director.instance('our_instance_group', '0', deployment_name: 'simple', include_credentials: false, env: client_env)

            expect(old_instance.vm_cid).to_not eq(new_instance.vm_cid)
          end

          it 'should use the new variable values on redeploy' do
            pre_second_deploy_invocations_size = current_sandbox.cpi.invocations.size
            deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, return_exit_code: true, include_credentials: false, env: client_env)
            invocations = current_sandbox.cpi.invocations.drop(pre_second_deploy_invocations_size)

            create_vm_invocation = invocations.select { |invocation| invocation.method_name == 'create_vm' }.last
            expect(create_vm_invocation.inputs['cloud_properties']).to eq({'availability_zone'=>'us-east-1a', 'ephemeral_disk'=>{'size'=>'2000','type'=>'gp1'}, 'instance_type'=>'m3.medium'})
          end
        end
      end
    end

    context 'all placeholders are NOT set in config server' do
      before do
        config_server_helper.put_value('/z1_cloud_properties', {'availability_zone' => 'us-east-1a'})
        config_server_helper.put_value('/z2_cloud_properties', {'availability_zone' => 'us-east-1b'})
        config_server_helper.put_value('/ephemeral_disk_placeholder', {'size' => '3000', 'type' => 'gp2'})
      end

      it 'errors on deploy' do
        expect {
          deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, return_exit_code: true, include_credentials: false, env: client_env)
        }.to raise_error
      end
    end

    context 'some placeholders have relative (non-absolute) path' do
      before do
        cloud_config['azs'][0]['cloud_properties'] = '((z1_cloud_properties))'
      end

      it 'does NOT error on update of cloud-config' do
        cloud_config_manifest = yaml_file('cloud_manifest', cloud_config)
        expect {
          bosh_runner.run("update-cloud-config #{cloud_config_manifest.path}", no_login: true, include_credentials: false, env: client_env)
        }.to_not raise_error
      end

      it 'errors on deploy' do
        expect {
          deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, return_exit_code: true, include_credentials: false, env: client_env)
        }.to raise_error(RuntimeError, /Relative paths are not allowed in this context. The following must be be switched to use absolute paths: 'z1_cloud_properties'/)
      end
    end
  end

  context 'cloud config contains cloud properties only placeholders' do
    let(:cloud_config) { Bosh::Spec::Deployments::cloud_config_with_cloud_properties_placeholders }

    let(:manifest_hash) do
      {
        'name' => 'simple',
        'director_uuid' => 'deadbeef',
        'releases' => [{'name' => 'bosh-release', 'version' => '0.1-dev'}],
        'update' => {
            'canaries' => 2,
            'canary_watch_time' => 4000,
            'max_in_flight' => 1,
            'update_watch_time' => 20
        },
        'instance_groups' => [{
            'name' => 'our_instance_group',
            'templates' => [{
                'name' => 'job_1_with_many_properties',
                'properties' => {
                    'gargamel' => {
                        'color' => 'pitch black'
                    }
                }
            }],
            'instances' => 1,
            'networks' => [{'name' => 'private'}],
            'properties' => {},
            'vm_type' => 'small',
            'persistent_disk_type' => 'small',
            'azs' => ['z1'],
            'stemcell' => 'default'
        }],
        'stemcells' => [{'alias' => 'default', 'os' => 'toronto-os', 'version' => '1'}]
      }
    end

    before do
      config_server_helper.put_value('/never-log-me', 'super-secret')
    end

    it 'does not log interpolated cloud properties in the task logs and deploy output' do
      deploy_output = deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false, env: client_env)
      expect(deploy_output).to_not include('super-secret')

      task_id = deploy_output.match(/^Task (\d+)$/)[1]

      debug_output = bosh_runner.run("task --debug --event --cpi --result #{task_id}", no_login: true, include_credentials: false, env: client_env)
      expect(debug_output).to_not include('super-secret')
    end

    context 'after a successful deployment' do
      before do
        deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, return_exit_code: true, include_credentials: false, env: client_env)
      end

      context 'deployment has unresponsive agents' do
        before {
          current_sandbox.cpi.kill_agents
        }

        it 'does not log interpolated cloud properties in the task logs during CCK - recreate VM' do
          recreate_vm = 3
          cck_output = bosh_run_cck_with_resolution(1, recreate_vm, client_env)

          expect_logs_not_to_contain('my-dep', Bosh::Spec::OutputParser.new(cck_output).task_id, ['super-secret'], log_options)
        end
      end
    end
  end

  context '#146889417 Expected variable to be already versioned in deployment' do
    let(:manifest_hash) {
      {"name"=>"foo-deployment",
       "director_uuid"=>nil,
       "releases"=>[{"name"=>"bosh-release", "version"=>"latest"}],
       "jobs"=>
        [{"azs"=>["z1"],
          "instances"=>1,
          "name"=>"hjMOn",
          "networks"=>[{"name"=>"j6XUS1M", "static_ips"=>["192.168.3.246"]}],
          "vm_type"=>"dMF8vIexnI",
          "templates"=>[{"name"=>"foobar", "release"=>"bosh-release"}],
          'stemcell'=>'default'}],
       "update"=>
        {"canaries"=>1,
         "canary_watch_time"=>4000,
         "max_in_flight"=>100,
         "update_watch_time"=>20},
      'stemcells'=> [{"os"=>"toronto-os", "version"=>1, 'alias'=>'default'}]
      }
    }

    let(:cloud_config_hash) {
      {"azs"=>[{"cloud_properties"=>{"hz4RwVr"=>"((/moVsfGUa))"}, "name"=>"z1"}],
       "compilation"=>{"network"=>"cAknaSb", "workers"=>1, "vm_type" => "dMF8vIexnI"},
       "networks"=>
           [{"name"=>"j6XUS1M",
             "subnets"=>
                 [{"azs"=>["z1"],
                   "cloud_properties"=>{},
                   "dns"=>["8.8.8.8"],
                   "gateway"=>"192.168.3.1",
                   "range"=>"192.168.3.0/24",
                   "reserved"=>
                       ["192.168.3.13",
                        "192.168.3.104-192.168.3.137",
                        "192.168.3.139-192.168.3.198"],
                   "static"=>["192.168.3.200-192.168.3.253"]}],
             "type"=>"manual"},
            {"name"=>"cAknaSb",
             "subnets"=>[{"cloud_properties"=>{}, "dns"=>["8.8.8.8"]}],
             "type"=>"dynamic"}],
       "vm_types"=>[{"cloud_properties"=>{}, "name"=>"dMF8vIexnI"}]}
    }

    before do
      config_server_helper.put_value('/moVsfGUa',"c8jNLgq")
    end

    it 'should not raise an error' do
      deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, return_exit_code: true, include_credentials: false, env: client_env)

      manifest = yaml_file('manifest', manifest_hash)
      bosh_runner.run("deploy #{manifest.path}", deployment_name: 'foo-deployment', return_exit_code: true, include_credentials: false, env: client_env)

      expect {
        bosh_runner.run("recreate", deployment_name: 'foo-deployment', return_exit_code: true, include_credentials: false, env: client_env)
      }.to_not raise_error
    end
  end

  context 'when persistent disks have variables in their cloud_properties' do
    let(:manifest) {
      {
        'name' => 'foo-deployment',
        'instance_groups' => [
          {
            'name' => 'ig_1',
            'instances' => 2,
            'vm_type' => 'default',
            'azs' => ['z1'],
            'networks' => [
              {
                'name' => 'default',
              }
            ],
            'persistent_disk_type' => 'default',
            'stemcell' => 'default',
            'jobs' => [
              {
                'name' => 'foobar',
                'release' => 'bosh-release'
              }
            ]
          }
        ],
        'releases' => [
          {
            'name' => 'bosh-release',
            'version' => '0+dev.1'
          }
        ],
        'stemcells' => [{
                          'alias' => 'default',
                          'os' => 'toronto-os',
                          'version' => 'latest'
                        }],
        'update' => {
          'canaries' => 5,
          'canary_watch_time' => 4000,
          'max_in_flight' => 2,
          'update_watch_time' => 20
        }
      }
    }

    let(:cloud_config) {
      {
        'azs' => [
          {
            'name' => 'z1'
          }
        ],
        'compilation' => {
          'az' => 'z1',
          'network' => 'default',
          'workers' => 1,
          'vm_type' => 'default'
        },
        'vm_types' => [
          'name' => 'default'
        ],
        'disk_types' => [
          {
            'cloud_properties' => {
              'prop_1' => '((/smurf_1))'
            },
            'disk_size' => 100,
            'name' => 'default'
          }
        ],
        'networks' => [
          {
            'name' => 'default',
            'subnets' => [
              {
                'azs' => ['z1'],
                'dns' => ['8.8.8.8'],
                'gateway' => '192.168.4.1',
                'range' => '192.168.4.0/24',
              }
            ],
            'type' => 'manual'
          }
        ]
      }
    }

    context 'when there are changes to variable value on config-server' do
      before do
        config_server_helper.put_value('/smurf_1', 'my_value_1')
        deploy_from_scratch(no_login: true, manifest_hash: manifest, cloud_config_hash: cloud_config, include_credentials: false, env: client_env)
        config_server_helper.put_value('/smurf_1', 'my_value_2')
      end

      it 'should update instances when redeploying' do
        created_instance = director.instances(deployment_name: 'foo-deployment', include_credentials: false, env: client_env)

        output = deploy_from_scratch(no_login: true, manifest_hash: manifest, cloud_config_hash: cloud_config, include_credentials: false, env: client_env)

        expect(created_instance.count).to eq(2)
        created_instance.each do |instance|
          expect(output).to include("Updating instance ig_1: ig_1/#{instance.id}")
        end
      end
    end

    context 'when there are NO changes to variables value on config-server' do
      before do
        config_server_helper.put_value('/smurf_1', 'my_value_1')
        deploy_from_scratch(no_login: true, manifest_hash: manifest, cloud_config_hash: cloud_config, include_credentials: false, env: client_env)
      end

      it 'should not make any updates when redeploying' do
        output = deploy_from_scratch(no_login: true, manifest_hash: manifest, cloud_config_hash: cloud_config, include_credentials: false, env: client_env)
        task_id = Bosh::Spec::OutputParser.new(output).task_id
        task_output = bosh_runner.run("task #{task_id} --debug", deployment_name: 'foo-deployment', include_credentials: false, env: client_env)
        expect(task_output).to include("No instances to update for 'ig_1'")
      end
    end
  end

  context 'cloud properties interpolation' do

    let(:manifest_hash) do
      {
        'name' => 'my-dep',
        'director_uuid' => 'deadbeef',
        'releases' => [{'name' => 'bosh-release', 'version' => '0.1-dev'}],
        'update' => {
          'canaries' => 2,
          'canary_watch_time' => 4000,
          'max_in_flight' => 1,
          'update_watch_time' => 20
        },
        'instance_groups' => [
          {
            'name' => 'instance_group_1',
            'jobs' => [
              {
                'name' => 'job_1_with_many_properties',
                'properties' => {
                  'gargamel' => {
                    'color' => 'pitch black'
                  }
                }
              }
            ],
            'instances' => 1,
            'networks' => [{'name' => 'private'}],
            'vm_extensions' => ['vm-extension-1'],
            'vm_type' => 'small',
            'persistent_disk_type' => 'normal_disk',
            'azs' => ['z1'],
            'stemcell' => 'default'
          }
        ],
        'stemcells' => [{'alias' => 'default', 'os' => 'toronto-os', 'version' => '1'}]
      }
    end

    let(:cloud_config_hash) do
      {
        'azs' => [
          {'name' => 'z1', 'cloud_properties' => {}},
          {'name' => 'z2', 'cloud_properties' => {}}
        ],

        'vm_types' => [
          {
            'name' => 'small',
            'cloud_properties' => {
              'instance_type' => 't2.micro'
            }
          },
          {
            'name' => 'medium',
            'cloud_properties' => {
              'instance_type' => 'm3.medium'
            }
          }
        ],

        'disk_types' => [
          {
          'name' => 'normal_disk',
          'disk_size' => 504,
          'cloud_properties' => {}
          }
        ],

        'vm_extensions' => [{'name' => 'vm-extension-1', 'cloud_properties' => {}}],

        'networks' => [
          {
            'name' => 'private',
            'type' => 'manual',
            'subnets' => [
              {
                'range' => '10.10.0.0/24',
                'gateway' => '10.10.0.1',
                'az' => 'z1',
                'static' => ['10.10.0.62'],
                'dns' => ['10.10.0.2'],
                'cloud_properties' => {}
              }, {
                'range' => '10.10.64.0/24',
                'gateway' => '10.10.64.1',
                'az' => 'z2',
                'static' => ['10.10.64.121', '10.10.64.122'],
                'dns' => ['10.10.0.2'],
                'cloud_properties' => {}
              }
            ]
          },
          {
            'name' => 'vip',
            'type' => 'vip',
            'cloud_properties' => {}
          }
        ],

        'compilation' => {
          'workers' => 10,
          'reuse_compilation_vms' => true,
          'az' => 'z1',
          'vm_type' => 'medium',
          'network' => 'private'
        }
      }
    end

    context 'azs cloud_properties' do
      before do
        cloud_config_hash['azs'][0]['cloud_properties'] = { 'smurf_1' => '((/smurf_1_variable))' }
        config_server_helper.put_value('/smurf_1_variable', 'cat_1')
      end

      it 'interpolates them correctly, sends interpolated values to CPI, records variable as used, and does not write interpolated values to logs' do
        output = deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false, env: client_env, deployment_name: 'my-dep')

        create_vm_invocations = current_sandbox.cpi.invocations_for_method('create_vm')
        expect(create_vm_invocations.size).to eq(1)
        expect(create_vm_invocations[0].inputs['cloud_properties']).to eq({'smurf_1' => 'cat_1', 'instance_type' => 't2.micro'})

        variables_names = table(bosh_runner.run('variables', json: true, include_credentials: false, deployment_name: 'my-dep', env: client_env)).map{|v| v['name']}
        expect(variables_names).to match_array(['/smurf_1_variable'])

        expect_logs_not_to_contain('my-dep', Bosh::Spec::OutputParser.new(output).task_id, ['cat_1'], log_options)
      end

      it 'does not update deployment when variables values do not change before a second deploy' do
        # First Deploy
        deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false, env: client_env, deployment_name: 'my-dep')

        # Second Deploy
        output = deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false, env: client_env, deployment_name: 'my-dep')
        expect(output).to_not include('Updating instance instance_group_1')

        task_id = Bosh::Spec::OutputParser.new(output).task_id
        task_output = bosh_runner.run("task #{task_id} --debug", deployment_name: 'my-dep', include_credentials: false, env: client_env)
        expect(task_output).to include("No instances to update for 'instance_group_1'")

        create_vm_invocations = current_sandbox.cpi.invocations_for_method('create_vm')
        expect(create_vm_invocations.size).to eq(1)
        expect(create_vm_invocations[0].inputs['cloud_properties']).to eq({'smurf_1' => 'cat_1', 'instance_type' => 't2.micro'})

        variables_names = table(bosh_runner.run('variables', json: true, include_credentials: false, deployment_name: 'my-dep', env: client_env)).map{|v| v['name']}
        expect(variables_names).to match_array(['/smurf_1_variable'])
      end

      context 'when variables value gets updated after deploying' do
        before do
          deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false, env: client_env, deployment_name: 'my-dep')
          config_server_helper.put_value('/smurf_1_variable', 'cat_2')
        end

        it 'updates the deployment with new values when deploying for second time' do
          output = deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false, env: client_env, deployment_name: 'my-dep')

          create_vm_invocations = current_sandbox.cpi.invocations_for_method('create_vm')
          expect(create_vm_invocations.size).to eq(2)
          expect(create_vm_invocations[1].inputs['cloud_properties']).to eq({'smurf_1' => 'cat_2', 'instance_type' => 't2.micro'})

          variables_names = table(bosh_runner.run('variables', json: true, include_credentials: false, deployment_name: 'my-dep', env: client_env)).map{|v| v['name']}
          expect(variables_names).to match_array(['/smurf_1_variable'])

          expect_logs_not_to_contain('my-dep', Bosh::Spec::OutputParser.new(output).task_id, ['cat_2'], log_options)
        end
      end
    end

    context 'vm_types cloud_properties' do
      before do
        cloud_config_hash['vm_types'][0]['cloud_properties']['smurf_1'] = '((/smurf_1_variable))'
        config_server_helper.put_value('/smurf_1_variable', 'cat_1')
      end

      it 'interpolates them correctly, sends interpolated values to CPI, records variable as used, and does not write interpolated values to logs' do
        output = deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false, env: client_env, deployment_name: 'my-dep')

        create_vm_invocations = current_sandbox.cpi.invocations_for_method('create_vm')
        expect(create_vm_invocations.size).to eq(1)
        expect(create_vm_invocations[0].inputs['cloud_properties']).to eq({'smurf_1' => 'cat_1', 'instance_type' => 't2.micro'})

        variables_names = table(bosh_runner.run('variables', json: true, include_credentials: false, deployment_name: 'my-dep', env: client_env)).map{|v| v['name']}
        expect(variables_names).to match_array(['/smurf_1_variable'])

        expect_logs_not_to_contain('my-dep', Bosh::Spec::OutputParser.new(output).task_id, ['cat_1'], log_options)
      end

      it 'does not update deployment when variables values do not change before a second deploy' do
        # First Deploy
        deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false, env: client_env, deployment_name: 'my-dep')

        # Second Deploy
        second_deploy_output = deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false, env: client_env, deployment_name: 'my-dep')

        task_id = Bosh::Spec::OutputParser.new(second_deploy_output).task_id
        task_output = bosh_runner.run("task #{task_id} --debug", deployment_name: 'my-dep', include_credentials: false, env: client_env)
        expect(task_output).to include("No instances to update for 'instance_group_1'")

        create_vm_invocations = current_sandbox.cpi.invocations_for_method('create_vm')
        expect(create_vm_invocations.size).to eq(1)
        expect(create_vm_invocations[0].inputs['cloud_properties']).to eq({'smurf_1' => 'cat_1', 'instance_type' => 't2.micro'})

        variables_names = table(bosh_runner.run('variables', json: true, include_credentials: false, deployment_name: 'my-dep', env: client_env)).map{|v| v['name']}
        expect(variables_names).to match_array(['/smurf_1_variable'])
      end

      context 'when variables value gets updated after deploying' do
        before do
          deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false, env: client_env, deployment_name: 'my-dep')
          config_server_helper.put_value('/smurf_1_variable', 'cat_2')
        end

        it 'updates the deployment with new values when deploying for second time' do
          deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false, env: client_env, deployment_name: 'my-dep')

          create_vm_invocations = current_sandbox.cpi.invocations_for_method('create_vm')
          expect(create_vm_invocations.size).to eq(2)
          expect(create_vm_invocations[1].inputs['cloud_properties']).to eq({'smurf_1' => 'cat_2', 'instance_type' => 't2.micro'})

          variables_names = table(bosh_runner.run('variables', json: true, include_credentials: false, deployment_name: 'my-dep', env: client_env)).map{|v| v['name']}
          expect(variables_names).to match_array(['/smurf_1_variable'])
        end
      end
    end

    context 'vm_extensions cloud_properties' do
      before do
        cloud_config_hash['vm_extensions'][0]['cloud_properties'] = { 'smurf_1' => '((/smurf_1_variable_vm_extension))' }
        config_server_helper.put_value('/smurf_1_variable_vm_extension', 'cat_1_vm_extension')
      end

      it 'interpolates them correctly, sends interpolated values to CPI, records variable as used, and does not write interpolated values to logs' do
        output = deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false, env: client_env, deployment_name: 'my-dep')

        create_vm_invocations = current_sandbox.cpi.invocations_for_method('create_vm')
        expect(create_vm_invocations.size).to eq(1)
        expect(create_vm_invocations[0].inputs['cloud_properties']).to eq({'smurf_1' => 'cat_1_vm_extension', 'instance_type' => 't2.micro'})

        variables_names = table(bosh_runner.run('variables', json: true, include_credentials: false, deployment_name: 'my-dep', env: client_env)).map{|v| v['name']}
        expect(variables_names).to match_array(['/smurf_1_variable_vm_extension'])

        expect_logs_not_to_contain('my-dep', Bosh::Spec::OutputParser.new(output).task_id, ['cat_1_vm_extension'], log_options)
      end

      it 'does not update deployment when variables values do not change before a second deploy' do
        # First Deploy
        deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false, env: client_env, deployment_name: 'my-dep')

        # Second Deploy
        second_deploy_output = deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false, env: client_env, deployment_name: 'my-dep')

        task_id = Bosh::Spec::OutputParser.new(second_deploy_output).task_id
        task_output = bosh_runner.run("task #{task_id} --debug", deployment_name: 'my-dep', include_credentials: false, env: client_env)
        expect(task_output).to include("No instances to update for 'instance_group_1'")

        create_vm_invocations = current_sandbox.cpi.invocations_for_method('create_vm')
        expect(create_vm_invocations.size).to eq(1)
        expect(create_vm_invocations[0].inputs['cloud_properties']).to eq({'smurf_1' => 'cat_1_vm_extension', 'instance_type' => 't2.micro'})

        variables_names = table(bosh_runner.run('variables', json: true, include_credentials: false, deployment_name: 'my-dep', env: client_env)).map{|v| v['name']}
        expect(variables_names).to match_array(['/smurf_1_variable_vm_extension'])
      end

      context 'when variables value gets updated after deploying' do
        before do
          deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false, env: client_env, deployment_name: 'my-dep')
          config_server_helper.put_value('/smurf_1_variable_vm_extension', 'cat_2_vm_extension')
        end

        it 'updates the deployment with new values when deploying for second time' do
          deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false, env: client_env, deployment_name: 'my-dep')

          create_vm_invocations = current_sandbox.cpi.invocations_for_method('create_vm')
          expect(create_vm_invocations.size).to eq(2)
          expect(create_vm_invocations[1].inputs['cloud_properties']).to eq({'smurf_1' => 'cat_2_vm_extension', 'instance_type' => 't2.micro'})

          variables_names = table(bosh_runner.run('variables', json: true, include_credentials: false, deployment_name: 'my-dep', env: client_env)).map{|v| v['name']}
          expect(variables_names).to match_array(['/smurf_1_variable_vm_extension'])
        end
      end
    end

    context 'disk_types cloud_properties' do
      before do
        cloud_config_hash['disk_types'][0]['cloud_properties'] = { 'smurf_1' => '((/smurf_1_variable))' }
        config_server_helper.put_value('/smurf_1_variable', 'cat_1_disk')
      end

      it 'interpolates them correctly, sends interpolated values to CPI, records variable as used, and does not write interpolated values to logs' do
        output = deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false, env: client_env, deployment_name: 'my-dep')

        create_disk_invocations = current_sandbox.cpi.invocations_for_method('create_disk')
        expect(create_disk_invocations.size).to eq(1)
        expect(create_disk_invocations[0].inputs['cloud_properties']).to eq({'smurf_1' => 'cat_1_disk'})

        variables_names = table(bosh_runner.run('variables', json: true, include_credentials: false, deployment_name: 'my-dep', env: client_env)).map{|v| v['name']}
        expect(variables_names).to match_array(['/smurf_1_variable'])

        expect_logs_not_to_contain('my-dep', Bosh::Spec::OutputParser.new(output).task_id, ['cat_1_disk'], log_options)
      end

      it 'does not update deployment when variables values do not change before a second deploy' do
        # First Deploy
        deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false, env: client_env, deployment_name: 'my-dep')

        # Second Deploy
        second_deploy_output = deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false, env: client_env, deployment_name: 'my-dep')

        task_id = Bosh::Spec::OutputParser.new(second_deploy_output).task_id
        task_output = bosh_runner.run("task #{task_id} --debug", deployment_name: 'my-dep', include_credentials: false, env: client_env)
        expect(task_output).to include("No instances to update for 'instance_group_1'")

        create_disk_invocations = current_sandbox.cpi.invocations_for_method('create_disk')
        expect(create_disk_invocations.size).to eq(1)
        expect(create_disk_invocations[0].inputs['cloud_properties']).to eq({'smurf_1' => 'cat_1_disk'})

        variables_names = table(bosh_runner.run('variables', json: true, include_credentials: false, deployment_name: 'my-dep', env: client_env)).map{|v| v['name']}
        expect(variables_names).to match_array(['/smurf_1_variable'])
      end

      context 'when variables value gets updated after deploying' do
        before do
          deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false, env: client_env, deployment_name: 'my-dep')
          config_server_helper.put_value('/smurf_1_variable', 'cat_2_disk')
        end

        it 'updates the deployment with new values when deploying for second time' do
          deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false, env: client_env, deployment_name: 'my-dep')

          create_disk_invocations = current_sandbox.cpi.invocations_for_method('create_disk')
          expect(create_disk_invocations.size).to eq(2)
          expect(create_disk_invocations[1].inputs['cloud_properties']).to eq({'smurf_1' => 'cat_2_disk'})

          variables_names = table(bosh_runner.run('variables', json: true, include_credentials: false, deployment_name: 'my-dep', env: client_env)).map{|v| v['name']}
          expect(variables_names).to match_array(['/smurf_1_variable'])
        end
      end
    end

    context 'networks cloud_properties' do
      context 'manual networks' do
        let(:networks) do
          [
            {
              'name' => 'private',
              'type' => 'manual',
              'subnets' => [
                {
                  'range' => '10.10.0.0/24',
                  'gateway' => '10.10.0.1',
                  'az' => 'z1',
                  'static' => ['10.10.0.62'],
                  'dns' => ['10.10.0.2'],
                  'cloud_properties' => {
                    'smurf_1' => '((/smurf_1_variable_manual_network))'
                  }
                }
              ]
            }
          ]
        end

        before do
          cloud_config_hash['networks'] = networks
          config_server_helper.put_value('/smurf_1_variable_manual_network', 'cat_1_manual_network')
        end

        it 'interpolates them correctly, sends interpolated values to CPI, records variable as used, and does not write interpolated values to logs' do
          output = deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false, env: client_env, deployment_name: 'my-dep')

          create_vm_invocations = current_sandbox.cpi.invocations_for_method('create_vm')
          expect(create_vm_invocations.size).to eq(1)
          expect(create_vm_invocations[0].inputs['networks']['private']['cloud_properties']).to eq({'smurf_1' => 'cat_1_manual_network'})

          variables_names = table(bosh_runner.run('variables', json: true, include_credentials: false, deployment_name: 'my-dep', env: client_env)).map{|v| v['name']}
          expect(variables_names).to match_array(['/smurf_1_variable_manual_network'])

          expect_logs_not_to_contain('my-dep', Bosh::Spec::OutputParser.new(output).task_id, ['cat_1_manual_network'], log_options)
        end

        it 'does not update deployment when variables values do not change before a second deploy' do
          # First Deploy
          deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false, env: client_env, deployment_name: 'my-dep')

          # Second Deploy
          second_deploy_output = deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false, env: client_env, deployment_name: 'my-dep')

          task_id = Bosh::Spec::OutputParser.new(second_deploy_output).task_id
          task_output = bosh_runner.run("task #{task_id} --debug", deployment_name: 'my-dep', include_credentials: false, env: client_env)
          expect(task_output).to include("No instances to update for 'instance_group_1'")

          create_vm_invocations = current_sandbox.cpi.invocations_for_method('create_vm')
          expect(create_vm_invocations.size).to eq(1)
          expect(create_vm_invocations[0].inputs['networks']['private']['cloud_properties']).to eq({'smurf_1' => 'cat_1_manual_network'})

          variables_names = table(bosh_runner.run('variables', json: true, include_credentials: false, deployment_name: 'my-dep', env: client_env)).map{|v| v['name']}
          expect(variables_names).to match_array(['/smurf_1_variable_manual_network'])
        end

        context 'when variables value gets updated after deploying' do
          before do
            deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false, env: client_env, deployment_name: 'my-dep')
            config_server_helper.put_value('/smurf_1_variable_manual_network', 'cat_2_manual_network')
          end

          it 'updates the deployment with new values when deploying for second time' do
            deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false, env: client_env, deployment_name: 'my-dep')

            create_vm_invocations = current_sandbox.cpi.invocations_for_method('create_vm')
            expect(create_vm_invocations.size).to eq(2)
            expect(create_vm_invocations[1].inputs['networks']['private']['cloud_properties']).to eq({'smurf_1' => 'cat_2_manual_network'})

            variables_names = table(bosh_runner.run('variables', json: true, include_credentials: false, deployment_name: 'my-dep', env: client_env)).map{|v| v['name']}
            expect(variables_names).to match_array(['/smurf_1_variable_manual_network'])
          end
        end
      end

      context 'dynamic networks' do
        let(:networks) do
          [
            {
              'name' => 'private',
              'type' => 'dynamic',
              'subnets' => [
                {
                  'az' => 'z1',
                  'cloud_properties' => {
                    'smurf_1' => '((/smurf_1_variable_dynamic_network))'
                  }
                }
              ]
            }
          ]
        end

        before do
          cloud_config_hash['networks'] = networks
          config_server_helper.put_value('/smurf_1_variable_dynamic_network', 'cat_1_dynamic_network')
        end

        it 'interpolates them correctly, sends interpolated values to CPI, records variable as used, and does not write interpolated values to logs' do
          output = deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false, env: client_env, deployment_name: 'my-dep')

          create_vm_invocations = current_sandbox.cpi.invocations_for_method('create_vm')
          expect(create_vm_invocations.size).to eq(1)
          expect(create_vm_invocations[0].inputs['networks']['private']['cloud_properties']).to eq({'smurf_1' => 'cat_1_dynamic_network'})

          variables_names = table(bosh_runner.run('variables', json: true, include_credentials: false, deployment_name: 'my-dep', env: client_env)).map{|v| v['name']}
          expect(variables_names).to match_array(['/smurf_1_variable_dynamic_network'])

          expect_logs_not_to_contain('my-dep', Bosh::Spec::OutputParser.new(output).task_id, ['cat_1_dynamic_network'], log_options)
        end

        it 'does not update deployment when variables values do not change before a second deploy' do
          # First Deploy
          deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false, env: client_env, deployment_name: 'my-dep')

          # Second Deploy
          second_deploy_output = deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false, env: client_env, deployment_name: 'my-dep')

          task_id = Bosh::Spec::OutputParser.new(second_deploy_output).task_id
          task_output = bosh_runner.run("task #{task_id} --debug", deployment_name: 'my-dep', include_credentials: false, env: client_env)
          expect(task_output).to include("No instances to update for 'instance_group_1'")

          create_vm_invocations = current_sandbox.cpi.invocations_for_method('create_vm')
          expect(create_vm_invocations.size).to eq(1)
          expect(create_vm_invocations[0].inputs['networks']['private']['cloud_properties']).to eq({'smurf_1' => 'cat_1_dynamic_network'})

          variables_names = table(bosh_runner.run('variables', json: true, include_credentials: false, deployment_name: 'my-dep', env: client_env)).map{|v| v['name']}
          expect(variables_names).to match_array(['/smurf_1_variable_dynamic_network'])
        end

        context 'when variables value gets updated after deploying' do
          before do
            deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false, env: client_env, deployment_name: 'my-dep')
            config_server_helper.put_value('/smurf_1_variable_dynamic_network', 'cat_2_dynamic_network')
          end

          it 'updates the deployment with new values when deploying for second time' do
            deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false, env: client_env, deployment_name: 'my-dep')

            create_vm_invocations = current_sandbox.cpi.invocations_for_method('create_vm')
            expect(create_vm_invocations.size).to eq(2)
            expect(create_vm_invocations[1].inputs['networks']['private']['cloud_properties']).to eq({'smurf_1' => 'cat_2_dynamic_network'})

            variables_names = table(bosh_runner.run('variables', json: true, include_credentials: false, deployment_name: 'my-dep', env: client_env)).map{|v| v['name']}
            expect(variables_names).to match_array(['/smurf_1_variable_dynamic_network'])
          end
        end
      end

      context 'vip networks' do
        let(:networks) do
          [
            {
              'name' => 'private',
              'type' => 'manual',
              'subnets' => [
                {
                  'range' => '10.10.0.0/24',
                  'gateway' => '10.10.0.1',
                  'az' => 'z1',
                  'static' => ['10.10.0.62'],
                  'dns' => ['10.10.0.2'],
                }
              ]
            },
            {
              'name' => 'vip',
              'type' => 'vip',
              'cloud_properties' => {
                'smurf_1' => '((/smurf_1_variable_vip_network))'
              }
            }
          ]
        end

        before do
          cloud_config_hash['networks'] = networks
          manifest_hash['instance_groups'][0]['networks'] = [
            {
              'name' => 'private',
              'default' => ['dns', 'gateway']
            },
            {
              'name' => 'vip',
              'static_ips' => ['8.8.8.8']
            }
          ]
          config_server_helper.put_value('/smurf_1_variable_vip_network', 'cat_1_vip_network')
        end

        it 'interpolates them correctly, sends interpolated values to CPI, records variable as used, and does not write interpolated values to logs' do
          output = deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false, env: client_env, deployment_name: 'my-dep')

          create_vm_invocations = current_sandbox.cpi.invocations_for_method('create_vm')
          expect(create_vm_invocations.size).to eq(1)
          expect(create_vm_invocations[0].inputs['networks']['vip']['cloud_properties']).to eq({'smurf_1' => 'cat_1_vip_network'})

          variables_names = table(bosh_runner.run('variables', json: true, include_credentials: false, deployment_name: 'my-dep', env: client_env)).map{|v| v['name']}
          expect(variables_names).to match_array(['/smurf_1_variable_vip_network'])

          expect_logs_not_to_contain('my-dep', Bosh::Spec::OutputParser.new(output).task_id, ['cat_1_vip_network'], log_options)
        end

        it 'does not update deployment when variables values do not change before a second deploy' do
          # First Deploy
          deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false, env: client_env, deployment_name: 'my-dep')

          # Second Deploy
          second_deploy_output = deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false, env: client_env, deployment_name: 'my-dep')

          task_id = Bosh::Spec::OutputParser.new(second_deploy_output).task_id
          task_output = bosh_runner.run("task #{task_id} --debug", deployment_name: 'my-dep', include_credentials: false, env: client_env)
          expect(task_output).to include("No instances to update for 'instance_group_1'")

          create_vm_invocations = current_sandbox.cpi.invocations_for_method('create_vm')
          expect(create_vm_invocations.size).to eq(1)
          expect(create_vm_invocations[0].inputs['networks']['vip']['cloud_properties']).to eq({'smurf_1' => 'cat_1_vip_network'})

          variables_names = table(bosh_runner.run('variables', json: true, include_credentials: false, deployment_name: 'my-dep', env: client_env)).map{|v| v['name']}
          expect(variables_names).to match_array(['/smurf_1_variable_vip_network'])
        end

        context 'when variables value gets updated after deploying' do
          before do
            deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false, env: client_env, deployment_name: 'my-dep')
            config_server_helper.put_value('/smurf_1_variable_vip_network', 'cat_2_vip_network')
          end

          it 'updates the deployment with new values when deploying for second time' do
            deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false, env: client_env, deployment_name: 'my-dep')

            create_vm_invocations = current_sandbox.cpi.invocations_for_method('create_vm')
            expect(create_vm_invocations.size).to eq(2)
            expect(create_vm_invocations[1].inputs['networks']['vip']['cloud_properties']).to eq({'smurf_1' => 'cat_2_vip_network'})

            variables_names = table(bosh_runner.run('variables', json: true, include_credentials: false, deployment_name: 'my-dep', env: client_env)).map{|v| v['name']}
            expect(variables_names).to match_array(['/smurf_1_variable_vip_network'])
          end
        end
      end
    end
  end
end
