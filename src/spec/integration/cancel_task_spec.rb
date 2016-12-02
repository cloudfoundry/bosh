require 'spec_helper'

describe 'cancel task', type: :integration do
  include Bosh::Spec::BlockingDeployHelper
  with_reset_sandbox_before_each

  it 'creates a task and then successfully cancels it' do
    cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
    cloud_config_hash['compilation']['workers'] = 1
    prepare_for_deploy(cloud_config_hash: cloud_config_hash)

    task_id = with_blocking_deploy do |task_id|
      output, exit_code = bosh_runner.run("cancel task #{task_id}", return_exit_code: true)
      expect(output).to include("Task #{task_id} is getting canceled")
      expect(exit_code).to eq(0)
    end

    task_event = events(task_id).last
    expect(task_event).to include('error')
    expect(task_event['error']['code']).to eq(10001)
    expect(task_event['error']['message']).to eq("Task #{task_id} cancelled")
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
