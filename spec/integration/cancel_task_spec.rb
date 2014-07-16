require 'spec_helper'

describe 'cancel task', type: :integration do
  with_reset_sandbox_before_each

  it 'creates a task and then successfully cancels it' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['compilation']['workers'] = 1
    manifest_hash['jobs'][0]['template'] = 'job_with_blocking_compilation'
    manifest_hash['jobs'][0]['instances'] = 1

    deploy_result = deploy_simple(manifest_hash: manifest_hash, no_track: true)
    task_id = Bosh::Spec::OutputParser.new(deploy_result).task_id('running')

    wait_for_package_compilation_vm

    output, exit_code = bosh_runner.run("cancel task #{task_id}", return_exit_code: true)
    expect(output).to include("Task #{task_id} is getting canceled")
    expect(exit_code).to eq(0)

    unblock_package_compilation

    task_event = events(task_id).last
    expect(task_event).to include('error')
    expect(task_event['error']['code']).to eq(10001)
    expect(task_event['error']['message']).to eq("Task #{task_id} cancelled")
  end

  def wait_for_package_compilation_vm
    waiter.wait(60) { director.vms.first || raise('Must have at least 1 VM') }
  end

  def unblock_package_compilation
    waiter.wait(300) do
      vm = director.vms.first || raise('Must have at least 1 VM')
      package_dir = vm.package_path('blocking_package')
      raise('Must find package dir') unless File.exists?(package_dir)
      FileUtils.touch(File.join(package_dir, 'unblock_packaging'))
    end
  end

  def events(task_id)
    result = bosh_runner.run("task #{task_id} --raw")
    event_list = []
    result.each_line do |line|
      begin
        event = Yajl::Parser.new.parse(line)
        event_list << event if event
      rescue Yajl::ParseError
      end
    end
    event_list
  end
end
