require_relative '../spec_helper'

describe 'fetching logs', type: :integration do
  with_reset_sandbox_before_each

  it 'can fetch job (default) and agent logs' do
    deploy_from_scratch(manifest_hash: Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)

    vm_0 = director.instance('foobar', '0')
    vm_0.write_job_log('toplevel.log', 'some top level log contents')
    vm_0.write_job_log('jobname/nested.log', 'some subdirector log contents')
    vm_0.write_job_log('logwithnoextension', 'some logfile with no extension contents')
    vm_0.write_agent_log('agentlog', 'foo')
    vm_0.write_agent_log('nested/agentlog', 'bar')

    expect(log_files).to match_array(['./toplevel.log', './jobname/nested.log', './logwithnoextension'])
    expect(log_files('--job jobname')).to match_array(['./toplevel.log', './jobname/nested.log', './logwithnoextension'])
    expect(log_files('--agent')).to match_array(['./agentlog', './nested/agentlog'])
  end

  def log_files(options = '')
    output = bosh_runner.run("logs foobar/0 #{options}", deployment_name: 'simple')

    expect(output).to include('Fetching logs for')
    expect(output).to include('Succeeded')

    tarball_path = %r{Downloading resource '.*' to '(?'log_location'.*)'}.match(output)[:log_location]

    Bosh::Spec::TarFileInspector.new(tarball_path).file_names
  end
end
