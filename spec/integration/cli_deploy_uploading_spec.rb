require 'spec_helper'

describe 'cli: deploy uploading', type: :integration do
  include Bosh::Spec::CreateReleaseOutputParsers
  with_reset_sandbox_before_each
  let(:stemcell_filename) { spec_asset('valid_stemcell.tgz') }

  context 'with a remote release' do
    let(:file_server) { Bosh::Spec::LocalFileServer.new(spec_asset(''), file_server_port, logger) }
    let(:file_server_port) { current_sandbox.port_provider.get_port(:releases_repo) }

    before { file_server.start }
    after { file_server.stop }

    let(:release_url) { file_server.http_url("compiled_releases/test_release/releases/test_release/test_release-1.tgz") }
    let(:release_sha) { '14ab572f7d00333d8e528ab197a513d44c709257' }

    it 'uploads the release from the remote url in the manifest' do
      cloud_config_manifest = yaml_file('cloud_manifest', Bosh::Spec::Deployments.simple_cloud_config)
      deployment_manifest = yaml_file('deployment_manifest', Bosh::Spec::Deployments.remote_release_manifest(release_url, release_sha))

      target_and_login
      bosh_runner.run("update cloud-config #{cloud_config_manifest.path}")
      bosh_runner.run("deployment #{deployment_manifest.path}")
      bosh_runner.run("upload stemcell #{stemcell_filename}")

      expect(bosh_runner.run('deploy')).to match /Deployed `minimal' to `Test Director'/
      expect(bosh_runner.run('cloudcheck --report')).to match(/No problems found/)
    end

    it 'fails when the sha1 does not match' do
      cloud_config_manifest = yaml_file('cloud_manifest', Bosh::Spec::Deployments.simple_cloud_config)
      deployment_manifest = yaml_file('deployment_manifest', Bosh::Spec::Deployments.remote_release_manifest(release_url, 'abcd1234'))

      target_and_login
      bosh_runner.run("update cloud-config #{cloud_config_manifest.path}")
      bosh_runner.run("deployment #{deployment_manifest.path}")
      bosh_runner.run("upload stemcell #{stemcell_filename}")

      output = bosh_runner.run('deploy', failure_expected: true)
      expect(output).to match /Release SHA1 `#{release_sha}' does not match the expected SHA1 `abcd1234'/
      expect(output).not_to match /Deployed `minimal' to `Test Director'/
    end

    it 'fails to deploy when the url is provided, but sha is not' do
      cloud_config_manifest = yaml_file('cloud_manifest', Bosh::Spec::Deployments.simple_cloud_config)
      deployment_manifest = yaml_file('deployment_manifest', Bosh::Spec::Deployments.remote_release_manifest(release_url, ''))

      target_and_login
      bosh_runner.run("update cloud-config #{cloud_config_manifest.path}")
      bosh_runner.run("deployment #{deployment_manifest.path}")
      bosh_runner.run("upload stemcell #{stemcell_filename}")

      output = bosh_runner.run('deploy', failure_expected: true)
      expect(output).to match /Expected SHA1 when specifying remote URL for release `test_release'/
      expect(output).not_to match /Deployed `minimal' to `Test Director'/
    end

    it 'fails to deploy when the url is invalid' do
      cloud_config_manifest = yaml_file('cloud_manifest', Bosh::Spec::Deployments.simple_cloud_config)
      deployment_manifest = yaml_file('deployment_manifest', Bosh::Spec::Deployments.remote_release_manifest('http://example.com/invalid_url', 'abcd1234'))

      target_and_login
      bosh_runner.run("update cloud-config #{cloud_config_manifest.path}")
      bosh_runner.run("deployment #{deployment_manifest.path}")
      bosh_runner.run("upload stemcell #{stemcell_filename}")

      output = bosh_runner.run('deploy', failure_expected: true)
      expect(output).to match /No release found/
      expect(output).not_to match /Deployed `minimal' to `Test Director'/
    end
  end

  context 'with a local release tarball' do
      let(:release_path) { spec_asset("compiled_releases/test_release/releases/test_release/test_release-1.tgz") }

    it 'uploads the release from the local file path in the manifest' do
      cloud_config_manifest = yaml_file('cloud_manifest', Bosh::Spec::Deployments.simple_cloud_config)
      deployment_manifest = yaml_file('deployment_manifest', Bosh::Spec::Deployments.local_release_manifest("file://" + release_path))

      target_and_login
      bosh_runner.run("update cloud-config #{cloud_config_manifest.path}")
      bosh_runner.run("deployment #{deployment_manifest.path}")
      bosh_runner.run("upload stemcell #{stemcell_filename}")

      expect(bosh_runner.run('deploy')).to match /Deployed `minimal' to `Test Director'/
      expect(bosh_runner.run('cloudcheck --report')).to match(/No problems found/)
    end

    it 'fails to deploy when the url is invalid' do
      cloud_config_manifest = yaml_file('cloud_manifest', Bosh::Spec::Deployments.simple_cloud_config)
      deployment_manifest = yaml_file('deployment_manifest', Bosh::Spec::Deployments.local_release_manifest('goobers'))

      target_and_login
      bosh_runner.run("update cloud-config #{cloud_config_manifest.path}")
      bosh_runner.run("deployment #{deployment_manifest.path}")
      bosh_runner.run("upload stemcell #{stemcell_filename}")

      output = bosh_runner.run('deploy', failure_expected: true)
      expect(output).to match /Invalid URL format for release `test_release' with URL `goobers'/
      expect(output).not_to match /Deployed `minimal' to `Test Director'/
    end

    it 'fails to deploy when the path is not a release' do
      cloud_config_manifest = yaml_file('cloud_manifest', Bosh::Spec::Deployments.simple_cloud_config)
      deployment_manifest = yaml_file('deployment_manifest', Bosh::Spec::Deployments.local_release_manifest('file:///goobers'))

      target_and_login
      bosh_runner.run("update cloud-config #{cloud_config_manifest.path}")
      bosh_runner.run("deployment #{deployment_manifest.path}")
      bosh_runner.run("upload stemcell #{stemcell_filename}")

      output = bosh_runner.run('deploy', failure_expected: true)
      expect(output).to match /Release file doesn't exist/
      expect(output).not_to match /Deployed `minimal' to `Test Director'/
    end
  end

  context 'with a remote stemcell' do
    let(:release_filename) { spec_asset("compiled_releases/test_release/releases/test_release/test_release-1.tgz") }

    let(:file_server) { Bosh::Spec::LocalFileServer.new(spec_asset(''), file_server_port, logger) }
    let(:file_server_port) { current_sandbox.port_provider.get_port(:releases_repo) }

    before { file_server.start }
    after { file_server.stop }

    let(:stemcell_url) { file_server.http_url("valid_stemcell.tgz") }
    let(:stemcell_sha) { '2ff0f2c5aac7ec46e0482d764fe8effed930bf0a' }

    it 'uploads the stemcell from the remote url in the manifest' do
      deployment_manifest = yaml_file('deployment_manifest', Bosh::Spec::Deployments.remote_stemcell_manifest(stemcell_url, stemcell_sha))

      target_and_login
      bosh_runner.run("deployment #{deployment_manifest.path}")
      bosh_runner.run("upload release #{release_filename}")

      expect(bosh_runner.run('deploy')).to match /Deployed `minimal' to `Test Director'/
      expect(bosh_runner.run('cloudcheck --report')).to match(/No problems found/)
    end

    it 'fails to deploy when the url is provided, but sha is not' do
      deployment_manifest = yaml_file('deployment_manifest', Bosh::Spec::Deployments.remote_stemcell_manifest(stemcell_url, ''))

      target_and_login
      bosh_runner.run("deployment #{deployment_manifest.path}")
      bosh_runner.run("upload release #{release_filename}")

      output = bosh_runner.run('deploy', failure_expected: true)
      expect(output).to match /Expected SHA1 when specifying remote URL for stemcell `ubuntu-stemcell'/
      expect(output).not_to match /Deployed `minimal' to `Test Director'/
    end

    it 'fails when the sha1 does not match' do
      deployment_manifest = yaml_file('deployment_manifest', Bosh::Spec::Deployments.remote_stemcell_manifest(stemcell_url, 'abcd1234'))

      target_and_login
      bosh_runner.run("deployment #{deployment_manifest.path}")
      bosh_runner.run("upload release #{release_filename}")

      output = bosh_runner.run('deploy', failure_expected: true)
      expect(output).to include "Stemcell SHA1 `#{stemcell_sha}' does not match the expected SHA1 `abcd1234'"
      expect(output).not_to match /Deployed `minimal' to `Test Director'/
    end
  end

  context 'with a local stemcell' do
    let(:release_filename) { spec_asset("compiled_releases/test_release/releases/test_release/test_release-1.tgz") }

    it 'uploads the stemcell from the local path in the manifest' do
      deployment_manifest = yaml_file('deployment_manifest', Bosh::Spec::Deployments.local_stemcell_manifest("file://" + stemcell_filename))
      # write a local stemcell manifest thing for us to use

      target_and_login
      bosh_runner.run("deployment #{deployment_manifest.path}")
      bosh_runner.run("upload release #{release_filename}")

      expect(bosh_runner.run('deploy')).to match /Deployed `minimal' to `Test Director'/
      expect(bosh_runner.run('cloudcheck --report')).to match(/No problems found/)
    end

    it 'fails to deploy when the path is not a stemcell' do
      cloud_config_manifest = yaml_file('cloud_manifest', Bosh::Spec::Deployments.simple_cloud_config)
      deployment_manifest = yaml_file('deployment_manifest', Bosh::Spec::Deployments.local_stemcell_manifest("file:///goobers"))

      target_and_login
      bosh_runner.run("update cloud-config #{cloud_config_manifest.path}")
      bosh_runner.run("deployment #{deployment_manifest.path}")
      bosh_runner.run("upload release #{release_filename}")

      output = bosh_runner.run('deploy', failure_expected: true)
      expect(output).to match /Stemcell is invalid, please fix, verify and upload again/
      expect(output).not_to match /Deployed `minimal' to `Test Director'/
    end

    it 'fails to deploy when the url is invalid' do
      cloud_config_manifest = yaml_file('cloud_manifest', Bosh::Spec::Deployments.simple_cloud_config)
      deployment_manifest = yaml_file('deployment_manifest', Bosh::Spec::Deployments.local_stemcell_manifest("goobers"))

      target_and_login
      bosh_runner.run("update cloud-config #{cloud_config_manifest.path}")
      bosh_runner.run("deployment #{deployment_manifest.path}")
      bosh_runner.run("upload release #{release_filename}")

      output = bosh_runner.run('deploy', failure_expected: true)
      expect(output).to match /Invalid URL format for stemcell `ubuntu-stemcell' with URL `goobers'. Supported schemes: file, http, https./
      expect(output).not_to match /Deployed `minimal' to `Test Director'/
    end
  end
end
