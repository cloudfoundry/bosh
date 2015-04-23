require 'spec_helper'

describe 'collocating templates from multiple releases', type: :integration do
  with_reset_sandbox_before_each

  context 'successfully collocating templates from different releases' do
    let(:manifest) do
      {
        'releases' => [
          { 'name' => 'dummy', 'version' => 'latest' },
          { 'name' => 'dummy2', 'version' => 'latest' },
        ],
        'jobs' => [{
          'name' => 'foobar',
          'templates' => [
            { 'name' => 'dummy_with_package', 'release' => 'dummy' },
            { 'name' => 'dummy',              'release' => 'dummy2' },
          ],
          'resource_pool' => 'a',
          'instances' => 1,
          'networks' => [{ 'name' => 'a' }]
        }]
      }
    end

    it 'successfully deploys' do
      target_and_login

      bosh_runner.run("upload release #{spec_asset('dummy-release.tgz')}")
      bosh_runner.run("upload release #{spec_asset('dummy2-release.tgz')}")
      bosh_runner.run("upload stemcell #{spec_asset('valid_stemcell.tgz')}")

      cloud_config_manifest = yaml_file('cloud_manifest', Bosh::Spec::Deployments.simple_cloud_config)
      bosh_runner.run("update cloud-config #{cloud_config_manifest.path}")

      manifest_hash = Bosh::Spec::Deployments.simple_manifest.merge(manifest)
      deployment_manifest = yaml_file('simple', manifest_hash)
      bosh_runner.run("deployment #{deployment_manifest.path}")
      bosh_runner.run("deploy")
    end
  end

  context 'when 2 templates depend on packages with the same name from different releases' do
    let(:manifest) do
      {
        'releases' => [
          { 'name' => 'dummy', 'version' => 'latest' },
          { 'name' => 'dummy2', 'version' => 'latest' },
        ],
        'jobs' => [{
          'name' => 'foobar',
          'templates' => [
            { 'name' => 'dummy_with_package', 'release' => 'dummy' },
            { 'name' => 'template2',          'release' => 'dummy2' },
          ],
          'resource_pool' => 'a',
          'instances' => 1,
          'networks' => [{ 'name' => 'a' }]
        }]
      }
    end

    it 'refuses to deploy' do
      target_and_login

      bosh_runner.run("upload release #{spec_asset('dummy-release.tgz')}")
      bosh_runner.run("upload release #{spec_asset('dummy2-release.tgz')}")
      bosh_runner.run("upload stemcell #{spec_asset('valid_stemcell.tgz')}")

      cloud_config_manifest = yaml_file('cloud_manifest', Bosh::Spec::Deployments.simple_cloud_config)
      bosh_runner.run("update cloud-config #{cloud_config_manifest.path}")

      manifest_hash = Bosh::Spec::Deployments.simple_manifest.merge(manifest)
      deployment_manifest = yaml_file('simple', manifest_hash)
      bosh_runner.run("deployment #{deployment_manifest.path}")

      output = bosh_runner.run("deploy", failure_expected: true)
      expect(output).to match(%r[Package name collision detected in job `foobar': template `dummy/dummy_with_package' depends on package `dummy/dummy_package',])
    end
  end
end
