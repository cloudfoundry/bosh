require 'spec_helper'

describe 'Using multiple CPIs', type: :integration do
  with_reset_sandbox_before_each

  let(:stemcell_filename) { asset_path('valid_stemcell.tgz') }
  let(:cloud_config) { SharedSupport::DeploymentManifestHelper.simple_cloud_config_with_multiple_azs_and_cpis }

  let(:cpi_config) do
    SharedSupport::DeploymentManifestHelper.multi_cpi_config(current_sandbox.sandbox_path(IntegrationSupport::Sandbox::EXTERNAL_CPI))
  end

  let(:instance_group) { SharedSupport::DeploymentManifestHelper.simple_instance_group(azs: %w[z1 z2]) }
  let(:deployment) { SharedSupport::DeploymentManifestHelper.test_release_manifest_with_stemcell.merge('instance_groups' => [instance_group]) }
  let(:cloud_config_manifest) { yaml_file('cloud_manifest', cloud_config) }
  let(:cpi_config_manifest) { yaml_file('cpi_manifest', cpi_config) }
  let(:deployment_manifest) { yaml_file('deployment_manifest', deployment) }

  before do
    create_and_upload_test_release

    bosh_runner.run("update-cloud-config #{cloud_config_manifest.path}")
    bosh_runner.run("update-cpi-config #{cpi_config_manifest.path}")
    bosh_runner.run("upload-stemcell #{stemcell_filename}")
  end

  context 'when multiple cpis that support different stemcell formats are configured' do
    let(:cpi_config) do
      cpi_config = SharedSupport::DeploymentManifestHelper.multi_cpi_config(
        current_sandbox.sandbox_path(IntegrationSupport::Sandbox::EXTERNAL_CPI),
      )
      cpi_config['cpis'][0]['properties'] = { 'formats' => ['other'] }
      cpi_config
    end

    context 'when a stemcell has been uploaded once' do
      it 'does not re-upload the tarball to the director' do
        output = bosh_runner.run("upload-stemcell #{stemcell_filename}")
        expect(output).to include("Stemcell 'ubuntu-stemcell/1' already exists")
      end

      context 'after adding a second CPI that supports the format' do
        before do
          cpi_config['cpis'] << {
            'name' => 'new-cpi',
            'type' => 'cpi-type',
            'properties' => {},
            'exec_path' => current_sandbox.sandbox_path(IntegrationSupport::Sandbox::EXTERNAL_CPI),
          }
          cpi_config_manifest = yaml_file('cpi_manifest', cpi_config)
          bosh_runner.run("update-cpi-config #{cpi_config_manifest.path}")
        end

        it 'reuploads the stemcell tarball to the new cpi' do
          output = bosh_runner.run("upload-stemcell #{stemcell_filename}")
          expect(output).to include(
            'Uploading stemcell ubuntu-stemcell/1 to the cloud (cpi: cpi-name2) (already exists, skipped)',
          )
          expect(output).to match(
            %r{Save stemcell ubuntu-stemcell/1 \(.+\) \(cpi: cpi-name2\) \(already exists, skipped\)},
          )
          expect(output).to include('Uploading stemcell ubuntu-stemcell/1 to the cloud (cpi: new-cpi)')
          expect(output).to match(%r{Save stemcell ubuntu-stemcell/1 \(.+\) \(cpi: new-cpi\)})
        end
      end
    end
  end

  context 'when a cpi is renamed' do
    context 'and the cpi config specifies migrated_from' do
      it 'can successfully delete the stemcell resource' do
        old_cpi_name = cpi_config['cpis'][0]['name']
        cpi_config['cpis'][0]['name'] = 'newcpiname'
        cpi_config['cpis'][1]['migrated_from'] = [{ 'name' => old_cpi_name }]

        cpi_config_manifest = yaml_file('cpi_manifest', cpi_config)
        bosh_runner.run("update-cpi-config #{cpi_config_manifest.path}")

        bosh_runner.run('delete-stemcell ubuntu-stemcell/1')
        out = table(bosh_runner.run('stemcells', json: true))
        expect(out).to be_empty
      end
    end

    context 'when migrating from the default cpi' do
      let(:empty_cpi_config) { yaml_file('empty_cpi_manifest', 'cpis' => []) }

      before do
        bosh_runner.run('delete-stemcell ubuntu-stemcell/1')
        bosh_runner.run('delete-config --type=cpi --name=default')
        bosh_runner.run("upload-stemcell #{stemcell_filename}")
      end

      it 'can successfully access the stemcell resource' do
        deployment['instance_groups'][0]['azs'] = ['z1']
        manifest = yaml_file('deployment_manifest', deployment)

        cpi_config['cpis'][0]['migrated_from'] = [{ 'name' => '' }]
        cpi_config['cpis'].pop

        cpi_config_manifest = yaml_file('cpi_manifest', cpi_config)
        bosh_runner.run("update-cpi-config #{cpi_config_manifest.path}")
        output = bosh_runner.run("upload-stemcell #{stemcell_filename}")
        expect(output).to include("Stemcell 'ubuntu-stemcell/1' already exists")

        bosh_runner.run('stemcells', json: true)
        bosh_runner.run("deploy #{manifest.path}", deployment_name: 'simple')

        bosh_runner.run('delete-deployment', deployment_name: 'simple')

        bosh_runner.run('delete-stemcell ubuntu-stemcell/1')
        out = table(bosh_runner.run('stemcells', json: true))
        expect(out).to be_empty
      end
    end

    context 'and cloud-config azs are updated' do
      context 'a deployment is updated' do
        it 'can successfully delete the vm resource' do
          # deploy with initial cpi config, and 2 azs
          output = bosh_runner.run("deploy #{deployment_manifest.path}", deployment_name: 'simple')
          expect(output).to include("Using deployment 'simple'")
          expect(output).to include('Succeeded')

          output = table(bosh_runner.run('instances', deployment_name: 'simple', json: true))
          expect(output).to contain_exactly(
            {
              'instance' => %r{foobar/.*},
              'process_state' => 'running',
              'az' => 'z1',
              'ips' => /.*/,
              'deployment' => 'simple',
            },
            {
              'instance' => %r{foobar/.*},
              'process_state' => 'running',
              'az' => 'z1',
              'ips' => /.*/,
              'deployment' => 'simple',
            },
            {
              'instance' => %r{foobar/.*},
              'process_state' => 'running',
              'az' => 'z2',
              'ips' => /.*/,
              'deployment' => 'simple',
            },
          )

          # start the transition of using new cpi names
          cpi_config['cpis'] = cpi_config['cpis'].concat(cpi_config['cpis'].map do |cpi|
            cpi2 = cpi.dup
            cpi2['name'] += '-new'
            cpi2
          end)
          cpi_config_manifest = yaml_file('cpi_manifest', cpi_config)
          bosh_runner.run("update-cpi-config #{cpi_config_manifest.path}")

          # tell our cloud-config to start using the new cpi names
          cloud_config['azs'] = cloud_config['azs'].map do |az|
            az['cpi'] += '-new'
            az
          end
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
              'instance' => %r{foobar/.*},
              'process_state' => 'running',
              'az' => 'z1',
              'ips' => /.*/,
              'deployment' => 'simple',
            },
            {
              'instance' => %r{foobar/.*},
              'process_state' => 'running',
              'az' => 'z2',
              'ips' => /.*/,
              'deployment' => 'simple',
            },
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
  end

  context 'when an az references a CPI that was deleted' do
    it 'fails to redeploy and orphans the VM associated with the deleted CPI', no_create_swap_delete: true do
      # deploy with initial cpi config, and 2 azs
      output = bosh_runner.run("deploy #{deployment_manifest.path}", deployment_name: 'simple')
      expect(output).to include("Using deployment 'simple'")
      expect(output).to include('Succeeded')

      output = table(bosh_runner.run('instances', deployment_name: 'simple', json: true))
      expect(output).to contain_exactly(
        {
          'instance' => %r{foobar/.*},
          'process_state' => 'running',
          'az' => 'z1',
          'ips' => /.*/,
          'deployment' => 'simple',
        },
        {
          'instance' => %r{foobar/.*},
          'process_state' => 'running',
          'az' => 'z1',
          'ips' => /.*/,
          'deployment' => 'simple',
        },
        { 'instance' => %r{foobar/.*},
          'process_state' => 'running',
          'az' => 'z2',
          'ips' => /.*/,
          'deployment' => 'simple' },
      )

      # Remove z2 CPI
      cpi_config['cpis'] = [cpi_config['cpis'][0]]
      cpi_config_manifest = yaml_file('cpi_manifest', cpi_config)
      bosh_runner.run("update-cpi-config #{cpi_config_manifest.path}")

      output = bosh_runner.run("deploy --recreate #{deployment_manifest.path}", deployment_name: 'simple', failure_expected: true)
      error_message = "CPI 'cpi-name2' not found in cpi-config"
      expect(output).to match(/#{error_message}/)

      # Bosh can't delete VM since its CPI no longer exists
      output = table(bosh_runner.run('vms', deployment_name: 'simple', json: true))
      expect(output).to contain_exactly(
        {
          'active' => 'true',
          'instance' => %r{foobar/.*},
          'process_state' => 'running',
          'stemcell' => 'ubuntu-stemcell/1',
          'az' => 'z1',
          'ips' => /.*/,
          'vm_cid' => /\d+/,
          'vm_type' => 'a',
        },
        {
          'active' => 'true',
          'instance' => %r{foobar/.*},
          'process_state' => 'running',
          'stemcell' => 'ubuntu-stemcell/1',
          'az' => 'z1',
          'ips' => /.*/,
          'vm_cid' => /\d+/,
          'vm_type' => 'a',
        },
        { 'active' => 'true',
          'instance' => %r{foobar/.*},
          'process_state' => 'stopped',
          'stemcell' => 'ubuntu-stemcell/1',
          'az' => 'z2',
          'ips' => /.*/,
          'vm_cid' => /\d+/,
          'vm_type' => 'a' },
      )
    end

    it 'fails to redeploy and orphans the VM associated with the deleted CPI', create_swap_delete: true do
      # deploy with initial cpi config, and 2 azs
      output = bosh_runner.run("deploy #{deployment_manifest.path}", deployment_name: 'simple')
      expect(output).to include("Using deployment 'simple'")
      expect(output).to include('Succeeded')

      output = table(bosh_runner.run('instances', deployment_name: 'simple', json: true))
      expect(output).to contain_exactly(
        {
          'instance' => %r{foobar/.*},
          'process_state' => 'running',
          'az' => 'z1',
          'ips' => /.*/,
          'deployment' => 'simple',
        },
        {
          'instance' => %r{foobar/.*},
          'process_state' => 'running',
          'az' => 'z1',
          'ips' => /.*/,
          'deployment' => 'simple',
        },
        { 'instance' => %r{foobar/.*},
          'process_state' => 'running',
          'az' => 'z2',
          'ips' => /.*/,
          'deployment' => 'simple' },
      )

      # Remove z2 CPI
      cpi_config['cpis'] = [cpi_config['cpis'][0]]
      cpi_config_manifest = yaml_file('cpi_manifest', cpi_config)
      bosh_runner.run("update-cpi-config #{cpi_config_manifest.path}")

      output = bosh_runner.run("deploy --recreate #{deployment_manifest.path}", deployment_name: 'simple', failure_expected: true)
      error_message = "CPI 'cpi-name2' not found in cpi-config"
      expect(output).to match(/#{error_message}/)

      # Bosh can't delete VM since its CPI no longer exists
      output = table(bosh_runner.run('vms', deployment_name: 'simple', json: true))
      expect(output).to contain_exactly(
        {
          'active' => 'true',
          'instance' => %r{foobar/.*},
          'process_state' => 'running',
          'stemcell' => 'ubuntu-stemcell/1',
          'az' => 'z1',
          'ips' => /.*/,
          'vm_cid' => /\d+/,
          'vm_type' => 'a',
        },
        {
          'active' => 'true',
          'instance' => %r{foobar/.*},
          'process_state' => 'running',
          'stemcell' => 'ubuntu-stemcell/1',
          'az' => 'z1',
          'ips' => /.*/,
          'vm_cid' => /\d+/,
          'vm_type' => 'a',
        },
        {
          'active' => 'false',
          'instance' => %r{foobar/.*},
          'process_state' => 'running',
          'stemcell' => 'ubuntu-stemcell/1',
          'az' => 'z1',
          'ips' => /.*/,
          'vm_cid' => /\d+/,
          'vm_type' => 'a',
        },
        {
          'active' => 'false',
          'instance' => %r{foobar/.*},
          'process_state' => 'running',
          'stemcell' => 'ubuntu-stemcell/1',
          'az' => 'z1',
          'ips' => /.*/,
          'vm_cid' => /\d+/,
          'vm_type' => 'a',
        },
        { 'active' => 'true',
          'instance' => %r{foobar/.*},
          'process_state' => 'running',
          'stemcell' => 'ubuntu-stemcell/1',
          'az' => 'z2',
          'ips' => /.*/,
          'vm_cid' => /\d+/,
          'vm_type' => 'a' },
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
          'instance' => %r{foobar/.*},
          'process_state' => 'running',
          'az' => 'z1',
          'ips' => /.*/,
          'deployment' => 'simple',
        },
        {
          'instance' => %r{foobar/.*},
          'process_state' => 'running',
          'az' => 'z1',
          'ips' => /.*/,
          'deployment' => 'simple',
        },
        { 'instance' => %r{foobar/.*},
          'process_state' => 'running',
          'az' => 'z2',
          'ips' => /.*/,
          'deployment' => 'simple' },
      )

      # Remove z2 from cloud config
      cloud_config['azs'] = [cloud_config['azs'][0]]
      cloud_config['networks'][0]['subnets'] = [cloud_config['networks'][0]['subnets'][0]]
      cloud_config_manifest = yaml_file('cloud_manifest', cloud_config)
      bosh_runner.run("update-cloud-config #{cloud_config_manifest.path}")

      # Remove z2 from new deploy
      instance_group = SharedSupport::DeploymentManifestHelper.simple_instance_group(azs: ['z1'])

      deployment = SharedSupport::DeploymentManifestHelper.test_release_manifest_with_stemcell.merge('instance_groups' => [instance_group])
      deployment_manifest = yaml_file('deployment_manifest', deployment)

      bosh_runner.run("deploy #{deployment_manifest.path}", deployment_name: 'simple')

      output = table(bosh_runner.run('vms', deployment_name: 'simple', json: true))
      expect(output).to contain_exactly(
        {
          'active' => 'true',
          'instance' => %r{foobar/.*},
          'process_state' => 'running',
          'stemcell' => 'ubuntu-stemcell/1',
          'az' => 'z1',
          'ips' => /.*/,
          'vm_cid' => /\d+/,
          'vm_type' => 'a',
        },
        {
          'active' => 'true',
          'instance' => %r{foobar/.*},
          'process_state' => 'running',
          'stemcell' => 'ubuntu-stemcell/1',
          'az' => 'z1',
          'ips' => /.*/,
          'vm_cid' => /\d+/,
          'vm_type' => 'a',
        },
        { 'active' => 'true',
          'instance' => %r{foobar/.*},
          'process_state' => 'running',
          'stemcell' => 'ubuntu-stemcell/1',
          'az' => 'z1',
          'ips' => /.*/,
          'vm_cid' => /\d+/,
          'vm_type' => 'a' },
      )
    end
  end
end
