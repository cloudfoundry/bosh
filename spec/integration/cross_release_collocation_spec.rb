require 'spec_helper'

describe 'collocating templates from multiple releases' do
  include IntegrationExampleGroup

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

      run_bosh("upload release #{spec_asset('dummy-release.tgz')}")
      run_bosh("upload release #{spec_asset('dummy2-release.tgz')}")
      run_bosh("upload stemcell #{spec_asset('valid_stemcell.tgz')}")

      manifest_hash = Bosh::Spec::Deployments.simple_manifest.merge(manifest)
      deployment_manifest = yaml_file('simple', manifest_hash)
      run_bosh("deployment #{deployment_manifest.path}")
      run_bosh("deploy")
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

      run_bosh("upload release #{spec_asset('dummy-release.tgz')}")
      run_bosh("upload release #{spec_asset('dummy2-release.tgz')}")
      run_bosh("upload stemcell #{spec_asset('valid_stemcell.tgz')}")

      manifest_hash = Bosh::Spec::Deployments.simple_manifest.merge(manifest)
      deployment_manifest = yaml_file('simple', manifest_hash)
      run_bosh("deployment #{deployment_manifest.path}")

      output = run_bosh("deploy", failure_expected: true)
      expect(output).to match(%r[Package name collision detected in job `foobar': template `dummy/dummy_with_package' depends on package `dummy/dummy_package',])
    end
  end
end
