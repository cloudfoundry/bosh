require_relative '../spec_helper'

describe 'Using multiple CPIs', type: :integration do
  with_reset_sandbox_before_each

  let(:stemcell_filename) { spec_asset('valid_stemcell.tgz') }
  let(:cloud_config) { Bosh::Spec::Deployments.simple_cloud_config_with_multiple_azs_and_cpis }
  let(:cpi_config) { Bosh::Spec::Deployments.simple_cpi_config(current_sandbox.sandbox_path(Bosh::Dev::Sandbox::Main::EXTERNAL_CPI)) }
  let(:job) { Bosh::Spec::Deployments.simple_job(:azs => ['z1', 'z2']) }
  let(:deployment) { Bosh::Spec::Deployments.test_release_manifest.merge('jobs' => [job]) }
  let(:cloud_config_manifest) { yaml_file('cloud_manifest', cloud_config) }
  let(:cpi_config_manifest) { yaml_file('cpi_manifest', cpi_config) }
  let(:deployment_manifest) { yaml_file('deployment_manifest', deployment) }

  before do
    create_and_upload_test_release

    bosh_runner.run("update-cloud-config #{cloud_config_manifest.path}")
    bosh_runner.run("update-cpi-config #{cpi_config_manifest.path}")
    bosh_runner.run("upload-stemcell #{stemcell_filename}")
  end

  context 'when an az references a CPI that was deleted' do
    it 'fails to redeploy and orphans the VM associated with the deleted CPI' do
      # deploy with initial cpi config, and 2 azs
      output = bosh_runner.run("deploy #{deployment_manifest.path}", deployment_name: 'simple')
      expect(output).to include("Using deployment 'simple'")
      expect(output).to include('Succeeded')

      output = table(bosh_runner.run('instances', deployment_name: 'simple', json: true))
      expect(output).to contain_exactly(
                            {
                                'instance' => /foobar\/.*/,
                                'process_state' => 'running',
                                'az' => 'z1',
                                'ips' => /.*/
                            },
                            {
                                'instance' => /foobar\/.*/,
                                'process_state' => 'running',
                                'az' => 'z1',
                                'ips' => /.*/
                            },
                            {
                                'instance' => /foobar\/.*/,
                                'process_state' => 'running',
                                'az' => 'z2',
                                'ips' => /.*/
                            }
                        )

      # Remove z2 CPI
      cpi_config['cpis'] = [cpi_config['cpis'][0]]
      cpi_config_manifest = yaml_file('cpi_manifest', cpi_config)
      bosh_runner.run("update-cpi-config #{cpi_config_manifest.path}")

      output = bosh_runner.run("deploy --recreate #{deployment_manifest.path}", deployment_name: 'simple', failure_expected: true)
      error_message = 'CPI was defined for AZ z2 but not found in cpi-config'
      expect(output).to match /#{error_message}/

      # Bosh can't delete VM since its CPI no longer exists
      output = table(bosh_runner.run('vms', deployment_name: 'simple', json: true))
      expect(output).to contain_exactly(
                            {
                                'instance' => /foobar\/.*/,
                                'process_state' => 'running',
                                'az' => 'z1',
                                'ips' => /.*/,
                                'vm_cid' => /\d+/,
                                'vm_type' => 'a',
                            },
                            {
                                'instance' => /foobar\/.*/,
                                'process_state' => 'running',
                                'az' => 'z1',
                                'ips' => /.*/,
                                'vm_cid' => /\d+/,
                                'vm_type' => 'a',
                            },
                            {
                                'instance' => /foobar\/.*/,
                                'process_state' => 'stopped',
                                'az' => 'z2',
                                'ips' => /.*/,
                                'vm_cid' => /\d+/,
                                'vm_type' => 'a',
                            }
                        )
    end
  end

  context 'when VM is deployed to az that has been removed from cloud config' do
    it 'falls back to existing CPIs and succeeds in deleting' do
      output = bosh_runner.run("deploy #{deployment_manifest.path}", deployment_name: 'simple')
      expect(output).to include("Using deployment 'simple'")
      expect(output).to include('Succeeded')

      output = table(bosh_runner.run('instances', deployment_name: 'simple', json: true))
      expect(output).to contain_exactly(
                            {
                                'instance' => /foobar\/.*/,
                                'process_state' => 'running',
                                'az' => 'z1',
                                'ips' => /.*/
                            },
                            {
                                'instance' => /foobar\/.*/,
                                'process_state' => 'running',
                                'az' => 'z1',
                                'ips' => /.*/
                            },
                            {
                                'instance' => /foobar\/.*/,
                                'process_state' => 'running',
                                'az' => 'z2',
                                'ips' => /.*/
                            }
                        )

      # Remove z2 from cloud config
      cloud_config['azs'] = [cloud_config['azs'][0]]
      cloud_config['networks'][0]['subnets'] = [cloud_config['networks'][0]['subnets'][0]]
      cloud_config_manifest = yaml_file('cloud_manifest', cloud_config)
      bosh_runner.run("update-cloud-config #{cloud_config_manifest.path}")

      # Remove z2 from new deploy
      job = Bosh::Spec::Deployments.simple_job(:azs => ['z1'])

      deployment = Bosh::Spec::Deployments.test_release_manifest.merge('jobs' => [job])
      deployment_manifest = yaml_file('deployment_manifest', deployment)

      bosh_runner.run("deploy #{deployment_manifest.path}", deployment_name: 'simple')

      output = table(bosh_runner.run('vms', deployment_name: 'simple', json: true))
      expect(output).to contain_exactly(
                            {
                                'instance' => /foobar\/.*/,
                                'process_state' => 'running',
                                'az' => 'z1',
                                'ips' => /.*/,
                                'vm_cid' => /\d+/,
                                'vm_type' => 'a',
                            },
                            {
                                'instance' => /foobar\/.*/,
                                'process_state' => 'running',
                                'az' => 'z1',
                                'ips' => /.*/,
                                'vm_cid' => /\d+/,
                                'vm_type' => 'a',
                            },
                            {
                                'instance' => /foobar\/.*/,
                                'process_state' => 'running',
                                'az' => 'z1',
                                'ips' => /.*/,
                                'vm_cid' => /\d+/,
                                'vm_type' => 'a',
                            }
                        )
    end
  end
end
