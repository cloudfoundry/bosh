# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe Bosh::Cli::TaskTracker do

  before(:each) do
    @cache = mock("cache")
    @director = mock("director", :uuid => "deadbeef",
                     :get_time_difference => 0.5)
    Bosh::Cli::Config.cache = @cache
  end

  def make_tracker(task_id, options)
    tracker = Bosh::Cli::TaskTracker.new(@director, task_id, options)
    tracker.stub!(:sleep)
    tracker
  end

  it "tracks director task event log" do
    tracker = make_tracker("42", {})
    @director.should_receive(:get_time_difference).and_return(0.5)

    @cache.should_receive(:read).with("task/deadbeef/42/event").and_return(nil)

    @director.should_receive(:get_task_state).with("42").
      and_return("queued", "queued", "processing", "processing", "done")

    @director.should_receive(:get_task_output).with("42", 0, "event").
      and_return(["", nil], ["", nil], ["foo\nbar", 8])

    @director.should_receive(:get_task_output).with("42", 8, "event").
      and_return(["\nba", 12])

    @director.should_receive(:get_task_output).with("42", 12, "event").
      and_return(["z", 13])

    @cache.should_receive(:write).
      with("task/deadbeef/42/event", "foo\nbar\nbaz\n")

    tracker.should_receive(:sleep).with(1).exactly(4).times

    tracker.track.should == :done
  end

  it "used cached task result if available" do
    tracker = make_tracker("42", { :log_type => "debug" })

    @cache.should_receive(:read).with("task/deadbeef/42/debug").
      and_return("foo\nbar\nbaz\n")

    @director.should_receive(:get_task_state).with("42").and_return("cancelled")

    tracker.track.should == :cancelled
  end

  it "uses appropriate renderer" do
    renderer = mock("renderer", :duration_known? => false)
    Bosh::Cli::TaskLogRenderer.should_receive(:create_for_log_type).
      with("foobar").and_return(renderer)

    tracker = make_tracker("42", { :log_type => "foobar" })

    @cache.should_receive(:read).with("task/deadbeef/42/foobar").and_return(nil)

    @director.should_receive(:get_task_state).with("42").
      and_return("queued", "processing", "done")

    @director.should_receive(:get_task_output).with("42", 0, "foobar").
      and_return(["", nil], ["foo\nbar", 8])

    @director.should_receive(:get_task_output).with("42", 8, "foobar").
      and_return(["\nbaz", 12])

    renderer.should_receive(:time_adjustment=).with(0.5)
    renderer.should_receive(:add_output).with("foo\n").ordered
    renderer.should_receive(:add_output).with("bar\n").ordered
    renderer.should_receive(:add_output).with("baz\n").ordered
    renderer.should_receive(:refresh).exactly(3).times
    renderer.should_receive(:finish).with(:done)

    tracker.should_receive(:sleep).with(1).exactly(2).times

    @cache.should_receive(:write).
      with("task/deadbeef/42/foobar", "foo\nbar\nbaz\n")

    tracker.track.should == :done
  end

  it "treats error and cancelled states as finished states" do
    %w(error cancelled).each do |state|
      tracker = make_tracker("42", { :log_type => "foobar",
                                     :use_cache => false })

      @director.should_receive(:get_task_state).with("42").
        and_return("queued", "processing", state)

      @director.should_receive(:get_task_output).with("42", 0, "foobar").
        and_return(["", nil], ["foo\nbar", 8])

      @director.should_receive(:get_task_output).with("42", 8, "foobar").
        and_return(["\nbaz", 12])

      tracker.should_receive(:sleep).with(1).exactly(2).times

      tracker.track.should == state.to_sym
    end
  end

  it "prompts for task cancel on interrupt (if in interactive mode)" do
    tracker = make_tracker("42", { :log_type => "foobar",
                                   :use_cache => false })

    tracker.stub!(:interactive?).and_return(true)

    @director.should_receive(:get_task_state).with("42").and_raise(Interrupt)
    @director.should_receive(:get_task_state).with("42").and_return("cancelled")
    @director.should_receive(:get_task_output).with("42", 0, "foobar").
      and_return(["", nil])

    tracker.should_receive(:ask).and_return("yes")
    @director.should_receive(:cancel_task).with("42")

    tracker.track.should == :cancelled
  end

end