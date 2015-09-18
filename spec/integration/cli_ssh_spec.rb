require 'spec_helper'

describe 'cli: ssh', type: :integration do
  with_reset_sandbox_before_each

  let(:runner) { bosh_runner_in_work_dir(ClientSandbox.test_release_dir) }
  let (:tmp_dir) { File.join(Bosh::Dev::Sandbox::Workspace.dir, "client-sandbox", "tmp") }

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

    FileUtils.mkdir_p(tmp_dir)

    `ssh-keygen -t rsa -P '' -f #{tmp_dir}/temp_key`
  end

  it 'adds agent host public key to temporary bosh known host file' do
    runner.run_interactively("ssh foobar 0 --default_password PASSWORD --public_key #{tmp_dir}/temp_key.pub") do | interactive_runner |
      expect(interactive_runner).to have_output 'Starting interactive shell'

      known_hosts_file_path = "/tmp/bosh_known_host"
      known_hosts = File.open(known_hosts_file_path, "rb").read
      known_host_array = known_hosts.split
      expect(known_host_array[1]).to eq("dummy-public-key")
    end

  end

end
