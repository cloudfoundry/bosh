require 'spec_helper'

describe 'cli: ssh', type: :integration do
  with_reset_sandbox_before_each

  let(:runner) { bosh_runner_in_work_dir(ClientSandbox.test_release_dir) }
  let (:ssh_dir) { File.join(Bosh::Dev::Sandbox::Workspace.dir, "client-sandbox", "home", ".ssh") }

  before do
    target_and_login
    runner.run('reset release')
    runner.run('create release --force')
    runner.run('upload release')

    runner.run("upload stemcell #{spec_asset('valid_stemcell.tgz')}")

    cloud_config_manifest = yaml_file('cloud_manifest', Bosh::Spec::Deployments.simple_cloud_config)
    bosh_runner.run("update cloud-config #{cloud_config_manifest.path}")

    manifest = Bosh::Spec::Deployments.simple_manifest
    deployment_manifest = yaml_file('deployment_manifest', manifest)

    runner.run("deployment #{deployment_manifest.path}")

    runner.run('deploy')

    FileUtils.mkdir_p(ssh_dir)
  end

  it 'adds agent host key to known host' do
    known_hosts_file_path = File.join(ssh_dir, "known_hosts")

    runner.run_interactively('ssh foobar 0 --default_password PASSWORD') do | interactive_runner |
      expect(interactive_runner).to have_output 'Starting interactive shell'

      known_hosts = File.open(known_hosts_file_path, "rb").read
      known_host_array = known_hosts.split
      expect(known_host_array[1]).to eq("dummy-public-key")
    end

  end

end
