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

    it 'uploads the release from the remote url in the manifest' do
      cloud_config_manifest = yaml_file('cloud_manifest', Bosh::Spec::Deployments.simple_cloud_config)
      deployment_manifest = yaml_file('deployment_manifest', Bosh::Spec::Deployments.remote_release_manifest(release_url))

      target_and_login
      bosh_runner.run("update cloud-config #{cloud_config_manifest.path}")
      bosh_runner.run("deployment #{deployment_manifest.path}")
      bosh_runner.run("upload stemcell #{stemcell_filename}")

      expect(bosh_runner.run('deploy')).to match /Deployed `minimal' to `Test Director'/
      expect(bosh_runner.run('cloudcheck --report')).to match(/No problems found/)
    end
  end

  it 'fails to deploy when the url is invalid' do
    cloud_config_manifest = yaml_file('cloud_manifest', Bosh::Spec::Deployments.simple_cloud_config)
    deployment_manifest = yaml_file('deployment_manifest', Bosh::Spec::Deployments.remote_release_manifest('http://example.com/invalid_url'))

    target_and_login
    bosh_runner.run("update cloud-config #{cloud_config_manifest.path}")
    bosh_runner.run("deployment #{deployment_manifest.path}")
    bosh_runner.run("upload stemcell #{stemcell_filename}")

    output = bosh_runner.run('deploy', failure_expected: true)
    expect(output).to match /No release found/
    expect(output).not_to match /Deployed `minimal' to `Test Director'/
  end
end
