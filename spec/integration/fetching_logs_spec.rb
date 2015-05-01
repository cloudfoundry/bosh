require 'spec_helper'
require 'pry'

describe 'fetching logs', type: :integration do
  with_reset_sandbox_before_each

  it 'can fetch job (default) and agent logs' do
    deploy_from_scratch

    vm_0 = director.vm('foobar/0')
    vm_0.write_job_log('toplevel.log', 'some top level log contents')
    vm_0.write_job_log('jobname/nested.log', 'some subdirector log contents')
    vm_0.write_job_log('logwithnoextension', 'some logfile with no extension contents')
    vm_0.write_agent_log('agentlog', 'foo')
    vm_0.write_agent_log('nested/agentlog', 'bar')

    expect(log_files).to match_array(['./toplevel.log', './jobname/nested.log', './logwithnoextension'])
    expect(log_files("--job")).to match_array(['./toplevel.log', './jobname/nested.log', './logwithnoextension'])
    expect(log_files("--agent")).to match_array(['./agentlog', './nested/agentlog'])
  end

  def log_files(options = "")
    output = bosh_runner.run("logs foobar 0 #{options}")

    expect(output).to include("Logs saved in")

    tarball_path = %r{Logs saved in `(?'log_location'.*)'}.match(output)[:log_location]

    Bosh::Spec::TarFileInspector.new(tarball_path).file_names
  end
end
