require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::Director::EventLog do

  def make_event_log(io)
    Bosh::Director::EventLog.new(io)
  end

  it "tracks stages and tasks, persists them using JSON" do
    buf = StringIO.new
    event_log = make_event_log(buf)
    event_log.total.should be_nil
    event_log.stage.should be_nil
    event_log.counter.should == 0

    event_log.begin_stage(:prepare, 5)
    event_log.stage.should == :prepare

    event_log.start_task(:foo, 1)
    event_log.start_task(:bar, 2)
    event_log.start_task(:baz, 3)

    event_log.finish_task(:bar, 2)
    event_log.finish_task(:baz, 3)
    event_log.finish_task(:foo, 1)

    event_log.begin_stage(:post_prepare, 256)
    event_log.stage.should == :post_prepare
    event_log.total.should == 256

    buf.rewind
    lines = buf.read.split("\n")
    events = lines.map { |line| JSON.parse(line) }

    events.size.should == 6

    events.map { |e| e["total"] }.uniq.should == [5]
    events.map { |e| e["index"] }.should == [1,2,3,2,3,1]
    events.map { |e| e["stage"] }.uniq.should == ["prepare"]
    events.map { |e| e["state"] }.should == [["started"]*3, ["finished"]*3].flatten
  end

  it "supports tracking parallel events" do
    buf = StringIO.new
    event_log = make_event_log(buf)

    event_log.begin_stage(:prepare, 5)

    threads = []

    5.times do |i|
      threads << Thread.new do
        sleep(rand()/5)
        event_log.track(i) do
          sleep(rand()/5)
        end
      end
    end

    threads.each { |thread| thread.join }

    buf.rewind
    lines = buf.read.split("\n")
    events = lines.map { |line| JSON.parse(line) }

    events.size.should == 10

    events.map { |e| e["total"] }.uniq.should == [5]
    events.map { |e| e["index"] }.sort.should == [1,1,2,2,3,3,4,4,5,5]
    events.map { |e| e["stage"] }.uniq.should == ["prepare"]
    events.map { |e| e["state"] }.sort.should == [["finished"]*5, ["started"]*5].flatten
  end

  it "doesn't enforce the proper event ordering or any other kind of consistency" do
    buf = StringIO.new
    event_log = make_event_log(buf)

    event_log.begin_stage(:prepare, 5)

    event_log.start_task(:foo, 1)
    event_log.start_task(:bar, 1)

    event_log.begin_stage(:run, 200)

    event_log.finish_task(:foo, 14)
    event_log.finish_task(:zbb, -500)

    buf.rewind
    lines = buf.read.split("\n")
    events = lines.map { |line| JSON.parse(line) }

    events.size.should == 4

    events.map { |e| e["total"] }.should == [5,5,200,200]
    events.map { |e| e["index"] }.should == [1,1,14,-500]
    events.map { |e| e["stage"] }.should == ["prepare", "prepare", "run", "run"]
  end

end
