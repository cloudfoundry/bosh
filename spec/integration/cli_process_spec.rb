require 'spec_helper'

describe 'cli: deployment process', type: :integration do
  with_reset_sandbox_before_each

  it 'successfully performed with minimal manifest' do
    release_filename = spec_asset('valid_release.tgz')
    deployment_manifest = yaml_file('minimal', Bosh::Spec::Deployments.minimal_manifest)

    target_and_login
    bosh_runner.run("deployment #{deployment_manifest.path}")
    bosh_runner.run("upload release #{release_filename}")

    out = bosh_runner.run('deploy')
    filename = File.basename(deployment_manifest.path)
    expect(out).to match /Deployed `#{filename}' to `Test Director'/
  end

  it 'successfully do two deployments from one release' do
    release_filename = spec_asset('valid_release.tgz')
    minimal_manifest = Bosh::Spec::Deployments.minimal_manifest
    deployment_manifest = yaml_file('minimal', minimal_manifest)

    target_and_login
    bosh_runner.run("deployment #{deployment_manifest.path}")
    bosh_runner.run("upload release #{release_filename}")

    filename = File.basename(deployment_manifest.path)
    expect(bosh_runner.run('deploy')).to match /Deployed `#{filename}' to `Test Director'/

    minimal_manifest['name'] = 'minimal2'
    deployment_manifest = yaml_file('minimal2', minimal_manifest)
    bosh_runner.run("deployment #{deployment_manifest.path}")

    filename = File.basename(deployment_manifest.path)
    expect(bosh_runner.run('deploy')).to match /Deployed `#{filename}' to `Test Director'/
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
    release_file = 'dev_releases/bosh-release-0+dev.1.tgz'
    release_filename = File.join(TEST_RELEASE_DIR, release_file)
    stemcell_filename = spec_asset('valid_stemcell.tgz') # Dummy stemcell (ubuntu-stemcell 1)

    Dir.chdir(TEST_RELEASE_DIR) do
      FileUtils.rm_rf('dev_releases')
      bosh_runner.run_in_current_dir('create release --with-tarball')
    end

    deployment_manifest = yaml_file('simple', Bosh::Spec::Deployments.simple_manifest)
    expect(File.exists?(release_filename)).to be(true)
    expect(File.exists?(deployment_manifest.path)).to be(true)

    target_and_login
    bosh_runner.run("deployment #{deployment_manifest.path}")
    bosh_runner.run("upload stemcell #{stemcell_filename}")
    bosh_runner.run("upload release #{release_filename}")

    filename = File.basename(deployment_manifest.path)
    expect(bosh_runner.run('deploy')).to match /Deployed `#{filename}' to `Test Director'/
    expect(bosh_runner.run('cloudcheck --report')).to match(/No problems found/)
  end

  it 'can delete deployment' do
    release_filename = spec_asset('valid_release.tgz')
    deployment_manifest = yaml_file('minimal', Bosh::Spec::Deployments.minimal_manifest)

    target_and_login
    bosh_runner.run("deployment #{deployment_manifest.path}")
    bosh_runner.run("upload release #{release_filename}")

    bosh_runner.run('deploy')
    expect(bosh_runner.run('delete deployment minimal')).to match(/Deleted deployment `minimal'/)
  end
end
