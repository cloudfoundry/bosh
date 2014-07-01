require 'spec_helper'

describe 'cancel task', type: :integration do
  with_reset_sandbox_before_each

  it 'spawns a job and then successfully cancel it' do
    deploy_result = deploy_simple(no_track: true)
    task_id = Bosh::Spec::OutputParser.new(deploy_result).task_id('running')

    output, exit_code = bosh_runner.run("cancel task #{task_id}", return_exit_code: true)
    expect(output).to match(/Task #{task_id} is getting canceled/)
    expect(exit_code).to eq(0)

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
