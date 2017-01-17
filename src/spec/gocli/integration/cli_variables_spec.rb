require_relative '../spec_helper'

describe 'cli: variables', type: :integration do
  with_reset_sandbox_before_each(config_server_enabled: true, user_authentication: 'uaa', uaa_encryption: 'asymmetric')

  let(:deployment_name) { manifest_hash['name'] }
  let(:director_name) { current_sandbox.director_name }
  let(:config_server_helper) { Bosh::Spec::ConfigServerHelper.new(current_sandbox, logger)}
  let(:manifest_hash) do
    Bosh::Spec::Deployments.test_release_manifest.merge(
      {
        'jobs' => [Bosh::Spec::Deployments.job_with_many_templates(
          name: '((ig_placeholder))',
          templates: [
            {'name' => 'job_with_property_types',
             'properties' => job_properties
            }
          ],
          instances: 1
        )]
      })
  end
  let(:cloud_config)  { Bosh::Spec::Deployments.simple_cloud_config }
  let(:client_env) { {'BOSH_CLIENT' => 'test', 'BOSH_CLIENT_SECRET' => 'secret', 'BOSH_CA_CERT' => "#{current_sandbox.certificate_path}"} }
  let(:job_properties) do
    {
      'gargamel' => {
        'secret_recipe' => 'poutine',
        'cert' => '((cert))'
      },
      'smurfs' => {
        'happiness_level' => '((happiness_level))',
        'phone_password' => '((/phone_password))'
      }
    }
  end

  def prepend_namespace(key)
    "/#{director_name}/#{deployment_name}/#{key}"
  end

  it 'should return list of placeholder variables' do
    config_server_helper.put_value(prepend_namespace('ig_placeholder'), 'my_group')
    config_server_helper.put_value(prepend_namespace('happiness_level'), '10')

    deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false, env: client_env)

    variables = table(bosh_runner.run('variables', json: true, include_credentials: false, deployment_name: deployment_name, env: client_env))

    variable_ids = variables.map { |obj|
      obj["ID"]
    }
    expect(variable_ids.uniq.length).to eq(4)

    variable_names = variables.map { |obj|
      obj["Name"]
    }
    expect(variable_names.uniq.length).to eq(4)

    expect(variable_names).to include("/#{director_name}/#{deployment_name}/ig_placeholder")
    expect(variable_names).to include("/#{director_name}/#{deployment_name}/cert")
    expect(variable_names).to include("/#{director_name}/#{deployment_name}/happiness_level")
    expect(variable_names).to include("/phone_password")
  end

  it 'should return list of placeholder variables for the runtime_config' do
    runtime_config = Bosh::Spec::Deployments.runtime_config_with_job_placeholders
    upload_runtime_config(runtime_config_hash: runtime_config, include_credentials: false,  env: client_env)

    config_server_helper.put_value('/release_name', 'bosh-release')
    config_server_helper.put_value('/gargamel_colour', 'cement-grey')

    config_server_helper.put_value(prepend_namespace('ig_placeholder'), 'my_group')
    config_server_helper.put_value(prepend_namespace('happiness_level'), '10')

    deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false, env: client_env)

    variables = table(bosh_runner.run('variables', json: true, include_credentials: false, deployment_name: deployment_name, env: client_env))

    variable_ids = variables.map { |obj|
      obj["ID"]
    }
    expect(variable_ids.uniq.length).to eq(6)

    variable_names = variables.map { |obj|
      obj["Name"]
    }
    expect(variable_names.uniq.length).to eq(6)

    expect(variable_names).to include("/release_name")
    expect(variable_names).to include("/gargamel_colour")
  end
end
