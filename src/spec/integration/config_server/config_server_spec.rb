require 'spec_helper'

describe 'using director with config server', type: :integration do
  with_reset_sandbox_before_each(config_server_enabled: true, user_authentication: 'uaa')

  let(:manifest_hash) do
    Bosh::Spec::DeploymentManifestHelper.test_release_manifest_with_stemcell.merge(
      'instance_groups' => [Bosh::Spec::DeploymentManifestHelper.instance_group_with_many_jobs(
        name: 'our_instance_group',
        jobs: [
          { 'name' => 'job_1_with_many_properties',
            'release' => 'bosh-release',
            'properties' => job_properties },
        ],
        instances: 1,
      )],
    )
  end
  let(:deployment_name) { manifest_hash['name'] }
  let(:director_name) { current_sandbox.director_name }
  let(:cloud_config)  { Bosh::Spec::DeploymentManifestHelper.simple_cloud_config }
  let(:config_server_helper) { Bosh::Spec::ConfigServerHelper.new(current_sandbox, logger) }
  let(:client_env) do
    { 'BOSH_CLIENT' => 'test', 'BOSH_CLIENT_SECRET' => 'secret', 'BOSH_CA_CERT' => current_sandbox.certificate_path.to_s }
  end
  let(:job_properties) do
    {
      'gargamel' => {
        'color' => '((my_placeholder))',
      },
    }
  end

  def prepend_namespace(key)
    "/#{director_name}/#{deployment_name}/#{key}"
  end

  context 'when config server certificates are trusted' do
    context 'when deployment manifest has variables' do
      context 'when some variables are not set in config server' do
        let(:job_properties) do
          {
            'smurfs' => {
              'color' => '((i_have_a_default_value))',
            },
            'gargamel' => {
              'color' => '((i_am_not_here_1))',
              'age' => '((i_am_not_here_2))',
              'dob' => '((i_am_not_here_3))',
            },
          }
        end

        it 'raises an error, even if a property has a default value in the job spec' do
          output, exit_code = deploy_from_scratch(
            manifest_hash: manifest_hash,
            cloud_config_hash: cloud_config,
            failure_expected: true,
            return_exit_code: true,
            include_credentials: false,
            env: client_env,
          )

          expect(exit_code).to_not eq(0)

          expect(output).to include <<~OUTPUT.strip
            Error: Unable to render instance groups for deployment. Errors are:
              - Unable to render jobs for instance group 'our_instance_group'. Errors are:
                - Unable to render templates for job 'job_1_with_many_properties'. Errors are:
                  - Failed to find variable '/TestDirector/simple/i_have_a_default_value' from config server: HTTP Code '404', Error: 'Name '/TestDirector/simple/i_have_a_default_value' not found'
                  - Failed to find variable '/TestDirector/simple/i_am_not_here_1' from config server: HTTP Code '404', Error: 'Name '/TestDirector/simple/i_am_not_here_1' not found'
                  - Failed to find variable '/TestDirector/simple/i_am_not_here_2' from config server: HTTP Code '404', Error: 'Name '/TestDirector/simple/i_am_not_here_2' not found'
                  - Failed to find variable '/TestDirector/simple/i_am_not_here_3' from config server: HTTP Code '404', Error: 'Name '/TestDirector/simple/i_am_not_here_3' not found'
          OUTPUT
        end
      end

      context 'when all variables are set in config server' do
        it 'does not log interpolated properties in the task debug logs and deploy output' do
          config_server_helper.put_value(prepend_namespace('my_placeholder'), 'he is colorless')

          deploy_output = deploy_from_scratch(
            manifest_hash: manifest_hash,
            cloud_config_hash: cloud_config,
            include_credentials: false,
            env: client_env,
          )
          expect(deploy_output).to_not include('he is colorless')

          task_id = deploy_output.match(/^Task (\d+)$/)[1]

          debug_output = bosh_runner.run(
            "task --debug --event --cpi --result #{task_id}",
            include_credentials: false,
            env: client_env,
          )
          expect(debug_output).to_not include('he is colorless')
        end

        it 'replaces variables in the manifest when config server has value for placeholders' do
          config_server_helper.put_value(prepend_namespace('my_placeholder'), 'cats are happy')

          deploy_from_scratch(
            manifest_hash: manifest_hash,
            cloud_config_hash: cloud_config,
            include_credentials: false,
            env: client_env,
          )

          instance = director.instance(
            'our_instance_group',
            '0',
            deployment_name: 'simple',
            json: true,
            include_credentials: false,
            env: client_env,
          )

          template_hash = YAML.safe_load(instance.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
          expect(template_hash['properties_list']['gargamel_color']).to eq('cats are happy')
        end

        it 'does not add namespace to keys starting with slash' do
          config_server_helper.put_value('/my_placeholder', 'cats are happy')
          job_properties['gargamel']['color'] = '((/my_placeholder))'

          deploy_from_scratch(
            manifest_hash: manifest_hash,
            cloud_config_hash: cloud_config,
            include_credentials: false,
            env: client_env,
          )
        end

        context 'mid string interpolation' do
          let(:job_properties) do
            {
              'gargamel' => {
                'color' => 'mild brownish ((my_placeholder)) yellowish ((smurf_age_placeholder))',
              },
            }
          end

          it 'replaces the variables in the manifest' do
            config_server_helper.put_value(prepend_namespace('my_placeholder'), 'greenish')
            config_server_helper.put_value(prepend_namespace('smurf_age_placeholder'), 9)
            deploy_from_scratch(
              manifest_hash: manifest_hash,
              cloud_config_hash: cloud_config,
              include_credentials: false,
              env: client_env,
            )

            instance = director.instance(
              'our_instance_group',
              '0',
              deployment_name: 'simple',
              json: true,
              include_credentials: false,
              env: client_env,
            )
            template_hash = YAML.safe_load(instance.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
            expect(template_hash['properties_list']['gargamel_color']).to eq('mild brownish greenish yellowish 9')
          end

          context 'when value returned by config server is not a string or a number' do
            let(:job_properties) do
              {
                'smurfs' => {
                  'color' => 'my color is ((my_placeholder_1))',
                },
                'gargamel' => {
                  'color' => 'smurf ((my_placeholder_2)) yellow ((my_placeholder_3))',
                },
              }
            end

            let(:my_placeholder_value) do
              {
                'cat' => 'meow',
                'dog' => 'woof',
              }
            end

            it 'errors' do
              config_server_helper.put_value(prepend_namespace('my_placeholder_1'), my_placeholder_value)
              config_server_helper.put_value(prepend_namespace('my_placeholder_2'), my_placeholder_value)
              config_server_helper.put_value(prepend_namespace('my_placeholder_3'), my_placeholder_value)

              output, exit_code = deploy_from_scratch(
                manifest_hash: manifest_hash,
                cloud_config_hash: cloud_config,
                failure_expected: true,
                return_exit_code: true,
                include_credentials: false,
                env: client_env,
              )

              expect(exit_code).to_not eq(0)
              expect(output).to include <<~OUTPUT.strip
                Error: Unable to render instance groups for deployment. Errors are:
                  - Unable to render jobs for instance group 'our_instance_group'. Errors are:
                    - Unable to render templates for job 'job_1_with_many_properties'. Errors are:
                      - Failed to substitute variable: Can not replace '((my_placeholder_1))' in 'my color is ((my_placeholder_1))'. The value should be a String or an Integer.
                      - Failed to substitute variable: Can not replace '((my_placeholder_2))' in 'smurf ((my_placeholder_2)) yellow ((my_placeholder_3))'. The value should be a String or an Integer.
                      - Failed to substitute variable: Can not replace '((my_placeholder_3))' in 'smurf ((my_placeholder_2)) yellow ((my_placeholder_3))'. The value should be a String or an Integer.
            OUTPUT
            end
          end
        end

        context 'with dot syntax' do
          let(:cloud_config_hash) { Bosh::Spec::DeploymentManifestHelper.simple_cloud_config }

          let(:manifest_hash) do
            manifest_hash = Bosh::Spec::DeploymentManifestHelper.simple_manifest_with_instance_groups
            manifest_hash['instance_groups'] = [{
              'name' => 'foobar',
              'jobs' => ['name' => 'job_1_with_many_properties', 'release' => 'bosh-release'],
              'vm_type' => 'a',
              'stemcell' => 'default',
              'instances' => 1,
              'networks' => [{ 'name' => 'a' }],
            }]
            manifest_hash
          end

          it 'replaces the variables in the manifest' do
            config_server_helper.put_value(prepend_namespace('my_placeholder'), 'text' => 'cats are angry')

            manifest_hash['instance_groups'][0]['jobs'][0]['properties'] = {
              'gargamel' => {
                'color' => '((my_placeholder.text))',
              },
            }
            deploy_from_scratch(
              manifest_hash: manifest_hash,
              cloud_config_hash: cloud_config_hash,
              include_credentials: false,
              env: client_env,
            )

            instance = director.instance(
              'foobar',
              '0',
              deployment_name: 'simple',
              json: true,
              include_credentials: false,
              env: client_env,
            )
            template_hash = YAML.safe_load(instance.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
            expect(template_hash['properties_list']['gargamel_color']).to eq('cats are angry')
          end

          it 'replaces nested variables in the manifest' do
            config_server_helper.put_value(prepend_namespace('my_placeholder_1'), 'cat' => { 'color' => { 'value' => 'orange' } })
            config_server_helper.put_value(prepend_namespace('my_placeholder_2'), 'cat' => { 'color' => { 'value' => 'black' } })
            config_server_helper.put_value(prepend_namespace('my_placeholder_3'), 'cat' => { 'color' => { 'value' => 'white' } })

            manifest_hash['instance_groups'][0]['jobs'][0]['properties'] = {
              'smurfs' => {
                'color' => 'I am a ((my_placeholder_2.cat.color.value)) cat. My kitten is ((my_placeholder_3.cat.color.value))',
              },
              'gargamel' => {
                'color' => '((my_placeholder_1.cat.color.value))',
              },
            }

            deploy_from_scratch(
              manifest_hash: manifest_hash,
              cloud_config_hash: cloud_config_hash,
              include_credentials: false,
              env: client_env,
            )

            instance = director.instance(
              'foobar',
              '0',
              deployment_name: 'simple',
              json: true,
              include_credentials: false,
              env: client_env,
            )
            template_hash = YAML.safe_load(instance.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
            expect(template_hash['properties_list']['smurfs_color']).to eq('I am a black cat. My kitten is white')
            expect(template_hash['properties_list']['gargamel_color']).to eq('orange')
          end

          it 'errors if all parts of nested variable is not found' do
            config_server_helper.put_value(prepend_namespace('my_placeholder'), 'cat' => { 'color' => { 'value' => 'orange' } })

            manifest_hash['instance_groups'][0]['jobs'][0]['properties'] = {
              'gargamel' => {
                'color' => '((my_placeholder.cat.dog.color.value))',
              },
            }

            output, exit_code = deploy_from_scratch(
              manifest_hash: manifest_hash,
              cloud_config_hash: cloud_config_hash,
              failure_expected: true,
              return_exit_code: true,
              include_credentials: false,
              env: client_env,
            )

            expect(exit_code).to_not eq(0)
            expect(output).to include(
              "Failed to fetch variable '#{prepend_namespace('my_placeholder')}' from config server: "\
                "Expected parent '#{prepend_namespace('my_placeholder')}.cat' hash to have key 'dog'",
            )
          end
        end

        context 'when manifest is downloaded through CLI' do
          before do
            job_properties.merge!('smurfs' => { 'color' => '((!smurfs_color_placeholder))' })
          end

          it 'returns original raw manifest (with no changes)' do
            config_server_helper.put_value(prepend_namespace('my_placeholder'), 'happy smurf')
            config_server_helper.put_value(prepend_namespace('smurfs_color_placeholder'), 'I am blue')

            deploy_from_scratch(
              manifest_hash: manifest_hash,
              cloud_config_hash: cloud_config,
              include_credentials: false,
              env: client_env,
            )

            downloaded_manifest = bosh_runner.run(
              'manifest',
              deployment_name: manifest_hash['name'],
              include_credentials: false,
              env: client_env,
            )

            expect(downloaded_manifest).to include '((my_placeholder))'
            expect(downloaded_manifest).to include '((!smurfs_color_placeholder))'
            expect(downloaded_manifest).to_not include 'happy smurf'
            expect(downloaded_manifest).to_not include 'I am blue'
          end
        end

        context 'when a variable starts with an exclamation mark' do
          let(:job_properties) do
            {
              'gargamel' => {
                'color' => '((!my_placeholder))',
              },
            }
          end

          it 'strips the exclamation mark when getting value from config server' do
            config_server_helper.put_value(prepend_namespace('my_placeholder'), 'cats are very happy')

            deploy_from_scratch(
              manifest_hash: manifest_hash,
              cloud_config_hash: cloud_config,
              include_credentials: false,
              env: client_env,
            )

            instance = director.instance(
              'our_instance_group',
              '0',
              deployment_name: 'simple',
              include_credentials: false,
              env: client_env,
            )

            template_hash = YAML.safe_load(instance.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
            expect(template_hash['properties_list']['gargamel_color']).to eq('cats are very happy')
          end
        end

        context 'when health monitor is around and resurrector is enabled' do
          with_reset_hm_before_each

          it 'interpolates values correctly when resurrector kicks in' do
            config_server_helper.put_value(prepend_namespace('my_placeholder'), 'cats are happy')

            deploy_from_scratch(
              manifest_hash: manifest_hash,
              cloud_config_hash: cloud_config,
              include_credentials: false,
              env: client_env,
            )
            instance = director.instance(
              'our_instance_group',
              '0',
              deployment_name: 'simple',
              include_credentials: false,
              env: client_env,
            )
            template_hash = YAML.safe_load(instance.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
            expect(template_hash['properties_list']['gargamel_color']).to eq('cats are happy')

            config_server_helper.put_value(prepend_namespace('my_placeholder'), 'smurfs are happy')

            director.kill_vm_and_wait_for_resurrection(
              instance,
              deployment_name: 'simple',
              include_credentials: false,
              env: client_env,
            )

            new_instance = director.instance(
              'our_instance_group',
              '0',
              deployment_name: 'simple',
              include_credentials: false,
              env: client_env,
            )
            template_hash = YAML.safe_load(new_instance.read_job_template(
                                             'job_1_with_many_properties',
                                             'properties_displayer.yml',
            ))
            expect(template_hash['properties_list']['gargamel_color']).to eq('cats are happy')
          end
        end
      end
    end
  end
end
