require 'spec_helper'

describe 'Bosh::Spec::IntegrationTest::CliUsage deployment process' do
  include IntegrationExampleGroup

  describe 'deployment process' do
    it 'successfully performed with minimal manifest' do
      release_filename = spec_asset('valid_release.tgz')
      deployment_manifest = yaml_file(
        'minimal', Bosh::Spec::Deployments.minimal_manifest)

      target_and_login
      run_bosh("deployment #{deployment_manifest.path}")
      run_bosh("upload release #{release_filename}")

      out = run_bosh('deploy')
      filename = File.basename(deployment_manifest.path)
      expect(out).to match /Deployed `#{filename}' to `Test Director'/
    end

    it 'successfully do two deployments from one release' do
      release_filename = spec_asset('valid_release.tgz')
      minimal_manifest = Bosh::Spec::Deployments.minimal_manifest
      deployment_manifest = yaml_file(
          'minimal', minimal_manifest)
      target_and_login
      run_bosh("deployment #{deployment_manifest.path}")
      run_bosh("upload release #{release_filename}")
      filename = File.basename(deployment_manifest.path)

      out = run_bosh('deploy')
      expect(out).to match /Deployed `#{filename}' to `Test Director'/
      minimal_manifest['name'] = 'minimal2'
      deployment_manifest = yaml_file(
          'minimal2', minimal_manifest)
      run_bosh("deployment #{deployment_manifest.path}")
      out = run_bosh('deploy')
      filename = File.basename(deployment_manifest.path)
      expect(out).to match /Deployed `#{filename}' to `Test Director'/
      expect_output('deployments', <<-OUT)
      +----------+--------------+-------------+
      | Name     | Release(s)   | Stemcell(s) |
      +----------+--------------+-------------+
      | minimal  | appcloud/0.1 |             |
      +----------+--------------+-------------+
      | minimal2 | appcloud/0.1 |             |
      +----------+--------------+-------------+

      Deployments total: 2
      OUT
    end

    it 'generates release and deploys it via simple manifest' do
      # Test release created with bosh (see spec/assets/test_release_template)
      release_file = 'dev_releases/bosh-release-0.1-dev.tgz'
      release_filename = File.join(TEST_RELEASE_DIR, release_file)
      # Dummy stemcell (ubuntu-stemcell 1)
      stemcell_filename = spec_asset('valid_stemcell.tgz')

      Dir.chdir(TEST_RELEASE_DIR) do
        FileUtils.rm_rf('dev_releases')
        run_bosh('create release --with-tarball', work_dir: Dir.pwd)
      end

      deployment_manifest = yaml_file(
        'simple', Bosh::Spec::Deployments.simple_manifest)

      expect(File.exists?(release_filename)).to be(true)
      expect(File.exists?(deployment_manifest.path)).to be(true)

      target_and_login
      run_bosh("deployment #{deployment_manifest.path}")
      run_bosh("upload stemcell #{stemcell_filename}")
      run_bosh("upload release #{release_filename}")

      out = run_bosh('deploy')
      filename = File.basename(deployment_manifest.path)
      expect(out).to match /Deployed `#{filename}' to `Test Director'/

      expect(run_bosh('cloudcheck --report')).to match /No problems found/
      expect($?).to eq 0
    end

    it 'can delete deployment' do
      release_filename = spec_asset('valid_release.tgz')
      deployment_manifest = yaml_file(
        'minimal', Bosh::Spec::Deployments.minimal_manifest)

      target_and_login
      run_bosh("deployment #{deployment_manifest.path}")
      run_bosh("upload release #{release_filename}")

      run_bosh('deploy')
      expect(run_bosh('delete deployment minimal')).to match /Deleted deployment `minimal'/
    end
  end
end
