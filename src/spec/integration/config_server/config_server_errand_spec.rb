require 'spec_helper'

describe 'using director with config server and a deployment with errands', type: :integration do
  with_reset_sandbox_before_each(config_server_enabled: true, user_authentication: 'uaa')

  let(:director_name) { current_sandbox.director_name }
  let(:config_server_helper) { Bosh::Spec::ConfigServerHelper.new(current_sandbox, logger) }
  let(:client_env) do
    { 'BOSH_CLIENT' => 'test',
      'BOSH_CLIENT_SECRET' => 'secret',
      'BOSH_CA_CERT' => current_sandbox.certificate_path.to_s }
  end
  let(:errand_manifest) { Bosh::Spec::Deployments.manifest_errand_with_placeholders }
  let(:namespaced_key) { "/#{director_name}/#{errand_manifest['name']}/placeholder" }
  let(:errand_password) { "/#{director_name}/#{errand_manifest['name']}/errand_password" }

  before do
    config_server_helper.put_value(errand_password, 'test123')
  end

  it 'replaces variables in properties' do
    config_server_helper.put_value(namespaced_key, 'some-smurfy-value')

    deploy_from_scratch(
      manifest_hash: errand_manifest,
      cloud_config_hash: Bosh::Spec::Deployments.simple_cloud_config,
      include_credentials: false,
      env: client_env,
    )

    errand_result = bosh_runner.run('run-errand fake-errand-name', deployment_name: 'errand', include_credentials: false,  env: client_env)
    expect(errand_result).to include('some-smurfy-value')
  end

  it 'interpolates errands variables at deploy time, NOT at runtime' do
    config_server_helper.put_value(namespaced_key, 'gargamel')

    deploy_from_scratch(
      manifest_hash: errand_manifest,
      cloud_config_hash: Bosh::Spec::Deployments.simple_cloud_config,
      include_credentials: false,
      env: client_env,
    )

    config_server_helper.put_value(namespaced_key, 'sharshabeel')

    errand_result = bosh_runner.run('run-errand fake-errand-name',
                                    deployment_name: 'errand',
                                    include_credentials: false,
                                    env: client_env)
    expect(errand_result).to include('gargamel')
    expect(errand_result).to_not include('sharshabeel')
    expect(errand_manifest['env']).to eq('bosh' => { 'password' => '((errand_password))' })
  end

  context 'when config server does NOT have the variable' do
    let(:errand_manifest) do
      manifest = Bosh::Spec::Deployments.manifest_errand_with_placeholders
      manifest['instance_groups'][1]['jobs'].first['properties']['errand1']['gargamel_color'] = '((gargamel_color_variable))'
      manifest
    end

    it 'displays a error messages at deploy time' do
      output, exit_code = deploy_from_scratch(
        manifest_hash: errand_manifest,
        cloud_config_hash: Bosh::Spec::Deployments.simple_cloud_config,
        include_credentials: false,
        env: client_env,
        failure_expected: true,
        return_exit_code: true
      )

      expect(exit_code).to_not eq(0)
      expect(output).to include <<-EOF.strip
Error: Unable to render instance groups for deployment. Errors are:
  - Unable to render jobs for instance group 'fake-errand-name'. Errors are:
    - Unable to render templates for job 'errand1'. Errors are:
      - Failed to find variable '/TestDirector/errand/placeholder' from config server: HTTP Code '404', Error: 'Name '/TestDirector/errand/placeholder' not found'
      - Failed to find variable '/TestDirector/errand/gargamel_color_variable' from config server: HTTP Code '404', Error: 'Name '/TestDirector/errand/gargamel_color_variable' not found'
      EOF
    end
  end
end
