require 'spec_helper'

describe 'cli: deployment process', type: :integration do
  include Bosh::Spec::CreateReleaseOutputParsers
  with_reset_sandbox_before_each
  let(:stemcell_filename) { spec_asset('valid_stemcell.tgz') }

  it 'generates release and deploys it via simple manifest' do
    # Test release created with bosh (see spec/assets/test_release_template)
    release_filename = Dir.chdir(ClientSandbox.test_release_dir) do
      FileUtils.rm_rf('dev_releases')
      output = bosh_runner.run_in_current_dir('create release --with-tarball')
      parse_release_tarball_path(output)
    end

    cloud_config_manifest = yaml_file('cloud_manifest', Bosh::Spec::Deployments.simple_cloud_config)
    deployment_manifest = yaml_file('deployment_manifest', Bosh::Spec::Deployments.simple_manifest)

    target_and_login
    bosh_runner.run("update cloud-config #{cloud_config_manifest.path}")
    bosh_runner.run("deployment #{deployment_manifest.path}")
    bosh_runner.run("upload stemcell #{stemcell_filename}")
    bosh_runner.run("upload release #{release_filename}")

    expect(bosh_runner.run('deploy')).to match /Deployed `simple' to `Test Director'/
    expect(bosh_runner.run('cloudcheck --report')).to match(/No problems found/)
  end

  describe 'bosh deploy' do
    context 'given two deployments from one release' do
      it 'is successful' do
        release_filename = spec_asset('test_release.tgz')
        minimal_manifest = Bosh::Spec::Deployments.minimal_manifest
        deployment_manifest = yaml_file('minimal_deployment', minimal_manifest)

        cloud_config = Bosh::Spec::Deployments.simple_cloud_config
        cloud_config['resource_pools'][0].delete('size')
        cloud_config_manifest = yaml_file('cloud_manifest', cloud_config)

        target_and_login
        bosh_runner.run("deployment #{deployment_manifest.path}")
        bosh_runner.run("upload release #{release_filename}")
        bosh_runner.run("upload stemcell #{stemcell_filename}")
        bosh_runner.run("update cloud-config #{cloud_config_manifest.path}")

        expect(bosh_runner.run('deploy')).to match /Deployed `minimal' to `Test Director'/

        minimal_manifest['name'] = 'minimal2'
        deployment_manifest = yaml_file('minimal2', minimal_manifest)
        bosh_runner.run("deployment #{deployment_manifest.path}")

        expect(bosh_runner.run('deploy')).to match /Deployed `minimal2' to `Test Director'/
        expect_output('deployments', <<-OUT)
          +----------+----------------+-------------------+--------------+
          | Name     | Release(s)     | Stemcell(s)       | Cloud Config |
          +----------+----------------+-------------------+--------------+
          | minimal  | test_release/1 | ubuntu-stemcell/1 | latest       |
          +----------+----------------+-------------------+--------------+
          | minimal2 | test_release/1 | ubuntu-stemcell/1 | latest       |
          +----------+----------------+-------------------+--------------+
          Deployments total: 2
        OUT
      end
    end
  end

  describe 'bosh deployments' do
    it 'lists deployment details' do
      release_filename = spec_asset('test_release.tgz')
      deployment_manifest = yaml_file('minimal', Bosh::Spec::Deployments.minimal_manifest)
      cloud_config_manifest = yaml_file('cloud_manifest', Bosh::Spec::Deployments.simple_cloud_config)

      target_and_login
      bosh_runner.run("update cloud-config #{cloud_config_manifest.path}")
      bosh_runner.run("deployment #{deployment_manifest.path}")
      bosh_runner.run("upload stemcell #{stemcell_filename}")
      bosh_runner.run("upload release #{release_filename}")

      out = bosh_runner.run('deploy')
      expect(out).to match /Deployed `minimal' to `Test Director'/

      deployments_output = bosh_runner.run('deployments')
      expect(deployments_output).to include(<<-OUT)
+---------+----------------+-------------------+--------------+
| Name    | Release(s)     | Stemcell(s)       | Cloud Config |
+---------+----------------+-------------------+--------------+
| minimal | test_release/1 | ubuntu-stemcell/1 | latest       |
+---------+----------------+-------------------+--------------+

Deployments total: 1
OUT
    end
  end

  describe 'bosh delete deployment' do
    it 'deletes an existing deployment' do
      release_filename = spec_asset('test_release.tgz')
      deployment_manifest = yaml_file('minimal', Bosh::Spec::Deployments.minimal_manifest)
      cloud_config_manifest = yaml_file('cloud_manifest', Bosh::Spec::Deployments.simple_cloud_config)

      target_and_login
      bosh_runner.run("update cloud-config #{cloud_config_manifest.path}")
      bosh_runner.run("deployment #{deployment_manifest.path}")
      bosh_runner.run("upload stemcell #{stemcell_filename}")
      bosh_runner.run("upload release #{release_filename}")

      bosh_runner.run('deploy')
      expect(bosh_runner.run('delete deployment minimal')).to match(/Deleted deployment `minimal'/)
    end

    it 'skips deleting of a non-existent deployment' do
      target_and_login
      expect(bosh_runner.run('delete deployment non-existent-deployment')).to match(/Skipped delete of missing deployment `non-existent-deployment'/)
    end
  end
end
