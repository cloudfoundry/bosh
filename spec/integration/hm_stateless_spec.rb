require "spec_helper"

describe 'health_monitor: 1', type: :integration do
  with_reset_sandbox_before_each

  before { current_sandbox.health_monitor_process.start }
  after { current_sandbox.health_monitor_process.stop }

  # ~1m20s
  it 'resurrects stateless nodes' do
    deploy_from_scratch

    original_vm = director.vm('foobar/0')
    original_vm.kill_agent
    resurrected_vm = director.wait_for_vm('foobar/0', 300)
    expect(resurrected_vm.cid).to_not eq(original_vm.cid)
  end

  it 'runs the pre-start scripts when the VM is resurrected' do
    manifest_hash = Bosh::Spec::Deployments.test_release_manifest.merge({
                        'jobs' => [Bosh::Spec::Deployments.job_with_many_templates(
                                       name: 'job_with_templates_having_prestart_scripts',
                                       templates: [
                                           {'name' => 'job_1_with_pre_start_script'},
                                           {'name' => 'job_2_with_pre_start_script'}
                                       ],
                                       instances: 1)]
                    })

    deploy_from_scratch({:manifest_hash => manifest_hash})

    original_vm = director.vm('job_with_templates_having_prestart_scripts/0')
    original_vm.kill_agent
    resurrected_vm = director.wait_for_vm('job_with_templates_having_prestart_scripts/0', 300)
    expect(resurrected_vm.cid).to_not eq(original_vm.cid)

    waiter = Bosh::Spec::Waiter.new(logger)
    waiter.wait(50) do
      agent_id = resurrected_vm.agent_id

      agent_log = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id}.log")
      expect(agent_log).to include("/jobs/job_1_with_pre_start_script/bin/pre-start' script has successfully executed")
      expect(agent_log).to include("/jobs/job_2_with_pre_start_script/bin/pre-start' script has successfully executed")

      job_1_stdout = File.read("#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id}/data/sys/log/job_1_with_pre_start_script/pre-start.stdout.log")
      expect(job_1_stdout).to match("message on stdout of job 1 pre-start script\ntemplate interpolation works in this script: this is pre_start_message_1")

      job_1_stderr = File.read("#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id}/data/sys/log/job_1_with_pre_start_script/pre-start.stderr.log")
      expect(job_1_stderr).to match('message on stderr of job 1 pre-start script')

      job_2_stdout = File.read("#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id}/data/sys/log/job_2_with_pre_start_script/pre-start.stdout.log")
      expect(job_2_stdout).to match('message on stdout of job 2 pre-start script')
    end
  end

  # ~8m
  it 'does not resurrect stateless nodes when paused' do
    deploy_from_scratch

    bosh_runner.run('vm resurrection foobar 0 off')
    original_vm = director.vm('foobar/0')
    original_vm.kill_agent
    expect(director.wait_for_vm('foobar/0', 150)).to be_nil
  end

  # ~4m
  it 'only resurrects stateless nodes that are configured to be resurrected' do
    skip 'The interaction of a resurrected node and a non-resurrected node are important but broken. See #69728124'

    deployment_hash = Bosh::Spec::Deployments.simple_manifest
    deployment_hash['jobs'][0]['instances'] = 2
    deploy_from_scratch(manifest_hash: deployment_hash)

    bosh_runner.run('vm resurrection foobar 1 off')

    original_0_vm = director.vm('foobar/0')
    original_1_vm = director.vm('foobar/1')

    # Kill VMs as close as possible
    original_0_vm.kill_agent
    original_1_vm.kill_agent

    new_0_vm = director.wait_for_vm('foobar/0', 150)
    expect(new_0_vm.cid).to_not eq(original_0_vm.cid)

    # Since at this point 0th VM is back up, assume that
    # if 1st VM would be resurrected it would've already happened
    # (i.e do not wait for long time)
    new_1_vm = director.wait_for_vm('foobar/1', 10)
    expect(new_1_vm).to be_nil
  end

  # ~3m
  it 'resurrects vms that were down before resurrector started' do
    # Turn resurrector off
    current_sandbox.reconfigure_health_monitor('health_monitor_without_resurrector.yml.erb')

    deployment_hash = Bosh::Spec::Deployments.simple_manifest
    deployment_hash['jobs'][0]['instances'] = 2
    deploy_from_scratch(manifest_hash: deployment_hash)

    director.vm('foobar/0').kill_agent
    director.vm('foobar/1').kill_agent

    _, exit_code = bosh_runner.run('cck --report', failure_expected: true, return_exit_code: true)
    expect(exit_code).to eq(1)

    # Turn resurrector back on
    current_sandbox.reconfigure_health_monitor('health_monitor.yml.erb')

    expect(director.wait_for_vm('foobar/0', 150)).to_not be_nil
    expect(director.wait_for_vm('foobar/1', 150)).to_not be_nil
  end

  # ~50s
  it 'notifies health monitor about job failures' do
    deployment_hash = Bosh::Spec::Deployments.simple_manifest
    deployment_hash['jobs'][0]['instances'] = 1
    deploy_from_scratch(manifest_hash: deployment_hash)

    director.vm('foobar/0').fail_job
    waiter.wait(20) { expect(health_monitor.read_log).to match(%r{\[ALERT\] Alert @ .* fake-monit-description}) }
  end
end
