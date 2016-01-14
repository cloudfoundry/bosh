require 'spec_helper'

describe 'deploy job with addons', type: :integration do
  with_reset_sandbox_before_each

  it 'collocates addon jobs with deployment jobs and evaluates addon properties' do
    target_and_login

    Dir.mktmpdir do |tmpdir|
      runtime_config_filename = File.join(tmpdir, 'runtime_config.yml')
      File.write(runtime_config_filename, Psych.dump(Bosh::Spec::Deployments.runtime_config_with_addon))
      expect(bosh_runner.run("update runtime-config #{runtime_config_filename}")).to include("Successfully updated runtime config")
    end

    bosh_runner.run("upload release #{spec_asset('bosh-release-0+dev.1.tgz')}")
    bosh_runner.run("upload release #{spec_asset('dummy2-release.tgz')}")

    upload_stemcell

    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    upload_cloud_config(manifest_hash: manifest_hash)
    deploy_simple_manifest(manifest_hash: manifest_hash)

    agent_id = director.vm('foobar', '0').agent_id
    expect(`ls #{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id}/data/jobs`.strip).to eq("dummy_with_properties\nfoobar")

    echo_statement = `find #{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id} -name "dummy_with_properties_ctl" | xargs cat | grep "prop_value"`
    expect(echo_statement.strip).to eq("echo 'prop_value'")
  end
end
