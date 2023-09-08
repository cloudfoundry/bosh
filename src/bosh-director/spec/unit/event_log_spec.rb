require 'spec_helper'

describe Bosh::Director::EventLog::Log do
  subject(:event_log) { described_class.new(task_db_writer) }

  let(:task_db_writer) { Bosh::Director::TaskDBWriter.new(column_name, task.id) }
  let(:task) { Bosh::Director::Models::Task.make(id: 42) }
  let(:column_name) { :event_output }

  it 'tracks stages and tasks, persists them using JSON' do
    stage1 = event_log.begin_stage(:stage1, 2)
    stage1.advance_and_track(:foo) do
      stage1.advance_and_track(:bar)
    end

    events = sent_events
    expect(events.size).to eq(4)
    expect(events.map { |e| e['total'] }.uniq).to eq([2])
    expect(events.map { |e| e['index'] }).to eq([1, 2, 2, 1])
    expect(events.map { |e| e['stage'] }.uniq).to eq(['stage1'])
    expect(events.map { |e| e['state'] }).to eq(%w[started started finished finished])
  end

  it 'supports tracking parallel events without being thread safe' \
     '(since stages can start in the middle of other stages)',
     truncation: true, if: ENV.fetch('DB', 'sqlite') != 'sqlite' do
    stage = event_log.begin_stage(:prepare, 5)
    threads = []

    5.times do |i|
      threads << Thread.new do
        sleep(rand / 5)
        stage.advance_and_track(i) { sleep(rand / 5) }
      end
    end

    threads.each(&:join)

    events = sent_events
    expect(events.size).to eq(10)
    expect(events.map { |e| e['total'] }.uniq).to eq([5])
    expect(events.map { |e| e['index'] }.sort).to eq([1, 1, 2, 2, 3, 3, 4, 4, 5, 5])
    expect(events.map { |e| e['stage'] }.uniq).to eq(['prepare'])
    expect(events.map { |e| e['state'] }.sort).to eq([['finished'] * 5, ['started'] * 5].flatten)
  end

  it 'supports tracking parallel events while being thread safe' \
     '(since stages can start in the middle of other stages)' do
    stage1 = event_log.begin_stage(:stage1, 2)
    stage2 = event_log.begin_stage(:stage2, 2)

    # stages are started and completed out of order
    stage1.advance_and_track(:stage1_task1)
    stage2.advance_and_track(:stage2_task1)
    stage1.advance_and_track(:stage1_task2)
    stage2.advance_and_track(:stage2_task2)

    events = sent_events
    expect(events.size).to eq(8)
    expect(events.map { |e| e['total'] }.uniq).to eq([2])
    expect(events.map { |e| e['index'] }).to eq([1, 1, 1, 1, 2, 2, 2, 2])
    expect(events.map { |e| e['stage'] }).to eq(%w[stage1 stage1 stage2 stage2 stage1 stage1 stage2 stage2])
    expect(events.map { |e| e['state'] }).to eq(%w[started finished started finished started finished started finished])
  end

  it 'does not enforce current task index consistency for a stage' do
    stage1 = event_log.begin_stage(:stage1, 2)
    stage1.advance_and_track(:stage1_task1)
    stage1.advance_and_track(:stage1_task2)
    stage1.advance_and_track(:stage1_task3) # over the total # of stages

    events = sent_events
    expect(events.size).to eq(6)
  end

  it 'issues deprecation warnings' do
    time = Time.now
    Timecop.freeze(time) do
      event_log.warn_deprecated('deprecation message')
    end

    expect(sent_events).to eq(
      [
        {
          'time' => time.to_i,
          'type' => 'deprecation',
          'message' => 'deprecation message',
        },
      ],
    )
  end

  it 'issues generic warnings' do
    time = Time.now
    Timecop.freeze(time) do
      event_log.warn('warning message')
    end

    expect(sent_events).to eq(
      [
        {
          'time' => time.to_i,
          'type' => 'warning',
          'message' => 'warning message',
        },
      ],
    )
  end

  def sent_events
    task.refresh
    task[:event_output].split("\n").map { |line| JSON.parse(line) }
  end
end
