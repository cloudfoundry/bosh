require 'spec_helper'

describe 'Bosh::Spec::IntegrationTest::CliUsage deployment process' do
  include IntegrationExampleGroup

  describe 'deployment process' do
    it 'successfully performed with minimal manifest' do
      release_filename = spec_asset('valid_release.tgz')
      deployment_manifest = yaml_file(
        'minimal', Bosh::Spec::Deployments.minimal_manifest)

      run_bosh("target http://localhost:#{current_sandbox.director_port}")
      run_bosh("deployment #{deployment_manifest.path}")
      run_bosh('login admin admin')
      run_bosh("upload release #{release_filename}")

      out = run_bosh('deploy')
      filename = File.basename(deployment_manifest.path)
      out.should =~ regexp("Deployed `#{filename}' to `Test Director'")
    end

    it 'generates release and deploys it via simple manifest' do
      # Test release created with bosh (see spec/assets/test_release_template)
      release_file = 'dev_releases/bosh-release-0.1-dev.tgz'
      release_filename = File.join(TEST_RELEASE_DIR, release_file)
      # Dummy stemcell (ubuntu-stemcell 1)
      stemcell_filename = spec_asset('valid_stemcell.tgz')

      Dir.chdir(TEST_RELEASE_DIR) do
        FileUtils.rm_rf('dev_releases')
        run_bosh('create release --with-tarball', Dir.pwd)
      end

      deployment_manifest = yaml_file(
        'simple', Bosh::Spec::Deployments.simple_manifest)

      File.exists?(release_filename).should be_true
      File.exists?(deployment_manifest.path).should be_true

      run_bosh("target http://localhost:#{current_sandbox.director_port}")
      run_bosh("deployment #{deployment_manifest.path}")
      run_bosh('login admin admin')
      run_bosh("upload stemcell #{stemcell_filename}")
      run_bosh("upload release #{release_filename}")

      out = run_bosh('deploy')
      filename = File.basename(deployment_manifest.path)
      out.should =~ regexp("Deployed `#{filename}' to `Test Director'")

      run_bosh('cloudcheck --report').should =~ regexp('No problems found')
      $?.should == 0
      # TODO: figure out which artifacts should be created by the given manifest
    end

    it 'can delete deployment' do
      release_filename = spec_asset('valid_release.tgz')
      deployment_manifest = yaml_file(
        'minimal', Bosh::Spec::Deployments.minimal_manifest)

      run_bosh("target http://localhost:#{current_sandbox.director_port}")
      run_bosh("deployment #{deployment_manifest.path}")
      run_bosh('login admin admin')
      run_bosh("upload release #{release_filename}")

      run_bosh('deploy')
      failure = regexp("Deleted deployment `minimal'")
      run_bosh('delete deployment minimal').should =~ failure
      # TODO: test that we don't have artefacts,
      # possibly upgrade to more featured deployment,
      # possibly merge to the previous spec
    end
  end
end
