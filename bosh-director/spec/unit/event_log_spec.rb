require "spec_helper"

describe Bosh::Director::EventLog::Log do
  subject(:event_log) { described_class.new(buf) }
  let(:buf) { StringIO.new }

  it "tracks stages and tasks, persists them using JSON" do
    stage1 = event_log.begin_stage(:prepare, 5)
    task1 = stage1.advance(:foo); task1.start
    task2 = stage1.advance(:bar); task2.start
    task3 = stage1.advance(:baz); task3.start

    task2.finish
    task3.finish
    task1.finish

    events = sent_events
    events.size.should == 6
    events.map { |e| e["total"] }.uniq.should == [5]
    events.map { |e| e["index"] }.should == [1,2,3,2,3,1]
    events.map { |e| e["stage"] }.uniq.should == ["prepare"]
    events.map { |e| e["state"] }.should == [["started"]*3, ["finished"]*3].flatten
  end

  it "supports tracking parallel events without being thread safe" +
     "(since stages can start in the middle of other stages)" do
    event_log.begin_stage(:prepare, 5)
    threads = []

    5.times do |i|
      threads << Thread.new do
        sleep(rand()/5)
        event_log.track(i) { sleep(rand()/5) }
      end
    end

    threads.each(&:join)

    events = sent_events
    events.size.should == 10
    events.map { |e| e["total"] }.uniq.should == [5]
    events.map { |e| e["index"] }.sort.should == [1,1,2,2,3,3,4,4,5,5]
    events.map { |e| e["stage"] }.uniq.should == ["prepare"]
    events.map { |e| e["state"] }.sort.should == [["finished"]*5, ["started"]*5].flatten
  end

  it "supports tracking parallel events while being thread safe" +
     "(since stages can start in the middle of other stages)" do
    stage1 = event_log.begin_stage(:stage1, 2)
    stage2 = event_log.begin_stage(:stage2, 2)

    # stages are started and completed out of order
    stage1.advance(:stage1_task1).tap { |t| t.start; t.finish }
    stage2.advance(:stage2_task1).tap { |t| t.start; t.finish }
    stage1.advance(:stage1_task2).tap { |t| t.start; t.finish }
    stage2.advance(:stage2_task2).tap { |t| t.start; t.finish }

    events = sent_events
    events.size.should == 8
    events.map { |e| e["total"] }.uniq.should == [2]
    events.map { |e| e["index"] }.should == [1,1,1,1,2,2,2,2]
    events.map { |e| e["stage"] }.should == ['stage1', 'stage1', 'stage2', 'stage2', 'stage1', 'stage1', 'stage2', 'stage2']
    events.map { |e| e["state"] }.should == ['started', 'finished', 'started', 'finished', 'started', 'finished', 'started', 'finished']
  end

  it 'does not enforce current task index consistency for a stage' do
    stage1 = event_log.begin_stage(:stage1, 2)
    stage1.advance(:stage1_task1).tap { |t| t.start; t.finish }
    stage1.advance(:stage1_task2).tap { |t| t.start; t.finish }
    stage1.advance(:stage1_task3).tap { |t| t.start; t.finish } # over the total # of stages

    events = sent_events
    events.size.should == 6
  end

  it 'has a default stage of unknown' do
    event_log.track(:task1)

    events = sent_events
    expect(events.size).to eq(2)
    expect(events.map { |e| e['total'] }).to eq([0,0])
    expect(events.map { |e| e['index'] }).to eq([1,1])
    expect(events.map { |e| e['stage'] }).to eq(['unknown', 'unknown'])
    expect(events.map { |e| e['state'] }).to eq(['started', 'finished'])
  end

  def sent_events
    buf.rewind
    buf.read.split("\n").map { |line| JSON.parse(line) }
  end
end
