require_relative '../spec_helper'

describe 'Using multiple CPIs', type: :integration do
  with_reset_sandbox_before_each

  let(:stemcell_filename) { spec_asset('valid_stemcell.tgz') }
  let(:cloud_config) { Bosh::Spec::NewDeployments.simple_cloud_config_with_multiple_azs_and_cpis }
  let(:cpi_config) { Bosh::Spec::Deployments.simple_cpi_config(current_sandbox.sandbox_path(Bosh::Dev::Sandbox::Main::EXTERNAL_CPI)) }
  let(:instance_group) { Bosh::Spec::NewDeployments.simple_instance_group(:azs => ['z1', 'z2']) }
  let(:deployment) { Bosh::Spec::NewDeployments.test_release_manifest_with_stemcell.merge('instance_groups' => [instance_group]) }
  let(:cloud_config_manifest) { yaml_file('cloud_manifest', cloud_config) }
  let(:cpi_config_manifest) { yaml_file('cpi_manifest', cpi_config) }
  let(:deployment_manifest) { yaml_file('deployment_manifest', deployment) }

  before do
    create_and_upload_test_release

    bosh_runner.run("update-cloud-config #{cloud_config_manifest.path}")
    bosh_runner.run("update-cpi-config #{cpi_config_manifest.path}")
    bosh_runner.run("upload-stemcell #{stemcell_filename}")
  end

  context 'when a cpi is renamed and cloud-config azs are updated' do
    context 'a deployment is updated' do
      it 'can successfully delete the vm resource' do
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

        # start the transition of using new cpi names
        cpi_config['cpis'] = cpi_config['cpis'].concat(cpi_config['cpis'].map { |cpi| cpi2=cpi.dup; cpi2['name'] += '-new'; cpi2 })
        puts "debug: #{cpi_config['cpis']}"
        cpi_config_manifest = yaml_file('cpi_manifest', cpi_config)
        bosh_runner.run("update-cpi-config #{cpi_config_manifest.path}")

        # tell our cloud-config to start using the new cpi names
        cloud_config['azs'] = cloud_config['azs'].map { |az| az['cpi'] += '-new'; az }
        cloud_config_manifest = yaml_file('cloud_manifest', cloud_config)
        bosh_runner.run("update-cloud-config #{cloud_config_manifest.path}")

        # reduce instance count, just to verify we can delete a vm during a live cpi transition
        deployment['instance_groups'][0]['instances'] = 2
        deployment_manifest = yaml_file('deployment_manifest', deployment)

        # deploy so we get onto the latest cloud-config/cpi names
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
            'az' => 'z2',
            'ips' => /.*/
          }
        )

        # now that our deployment is on the latest cloud-config, it no longer has a dependence on the old cpi names
        # so, remove the old cpi names
        cpi_config['cpis'] = cpi_config['cpis'].select { |cpi| cpi['name'] =~ /-new$/ }
        cpi_config_manifest = yaml_file('cpi_manifest', cpi_config)
        bosh_runner.run("update-cpi-config #{cpi_config_manifest.path}")

        # delete the deployment, just to verify we can delete vms even though the original cpi names are gone
        output = bosh_runner.run('delete-deployment', deployment_name: 'simple')
        expect(output).to include("Using deployment 'simple'")
        expect(output).to include('Succeeded')
      end
    end
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
      error_message = "Failed to load CPI for AZ 'z2': CPI 'cpi-name2' not found in cpi-config"
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
      instance_group = Bosh::Spec::NewDeployments.simple_instance_group(:azs => ['z1'])

      deployment = Bosh::Spec::NewDeployments.test_release_manifest_with_stemcell.merge('instance_groups' => [instance_group])
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
