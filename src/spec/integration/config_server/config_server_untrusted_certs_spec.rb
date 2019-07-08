require_relative '../../spec_helper'

describe 'using director with config server and the certs are not trusted', type: :integration do
  with_reset_sandbox_before_each(config_server_enabled: true, with_config_server_trusted_certs: false, user_authentication: 'uaa')

  let(:manifest_hash) do
    Bosh::Spec::NewDeployments.test_release_manifest_with_stemcell.merge(
      {
        'instance_groups' => [Bosh::Spec::NewDeployments.instance_group_with_many_jobs(
          name: 'our_instance_group',
          jobs: [
            {'name' => 'job_1_with_many_properties',
             'release' => 'bosh-release',
             'properties' => {
               'gargamel' => {
                 'color' => '((my_placeholder))'
               },
               'smurfs' => {
                 'happiness_level' => 10
               }
             }
            }
          ],
          instances: 1
        )]
      })
  end

  let(:cloud_config)  { Bosh::Spec::NewDeployments.simple_cloud_config }
  let(:client_env) do
    { 'BOSH_CLIENT' => 'test', 'BOSH_CLIENT_SECRET' => 'secret', 'BOSH_CA_CERT' => current_sandbox.certificate_path.to_s }
  end

  it 'throws certificate validator error' do
    output, exit_code = deploy_from_scratch(no_login: true, manifest_hash: manifest_hash,
                                            cloud_config_hash: cloud_config, failure_expected: true,
                                            return_exit_code: true, include_credentials: false, env: client_env)

    expect(exit_code).to_not eq(0)
    expect(output).to include('certificate verify failed')
  end
end
