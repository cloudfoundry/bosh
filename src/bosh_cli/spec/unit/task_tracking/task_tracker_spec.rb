require "spec_helper"

describe Bosh::Cli::TaskTracking::TaskTracker do
  before { @director = instance_double('Bosh::Cli::Client::Director', :uuid => "deadbeef", :get_time_difference => 0.5) }

  def make_tracker(task_id, options)
    described_class.new(@director, task_id, options).tap do |t|
      allow(t).to receive(:sleep)
    end
  end

  it "tracks director task event log" do
    tracker = make_tracker("42", {})
    expect(@director).to receive(:get_time_difference).and_return(0.5)

    expect(@director).to receive(:get_task_state).with("42").
      and_return("queued", "queued", "processing", "processing", "done")

    expect(@director).to receive(:get_task_output).with("42", 0, "event").
      and_return(["", nil], ["", nil], ["foo\nbar", 8])

    expect(@director).to receive(:get_task_output).with("42", 8, "event").
      and_return(["\nba", 12])

    expect(@director).to receive(:get_task_output).with("42", 12, "event").
      and_return(["z", 13])

    expect(tracker).to receive(:sleep).with(1).exactly(4).times

    expect(tracker.track).to eq(:done)
  end

  it "uses appropriate renderer" do
    renderer = double("renderer", :duration_known? => false)
    expect(Bosh::Cli::TaskTracking::TaskLogRenderer).to receive(:create_for_log_type).
      with("foobar").and_return(renderer)

    tracker = make_tracker("42", { :log_type => "foobar" })

    expect(@director).to receive(:get_task_state).with("42").
      and_return("queued", "processing", "done")

    expect(@director).to receive(:get_task_output).with("42", 0, "foobar").
      and_return(["", nil], ["foo\nbar", 8])

    expect(@director).to receive(:get_task_output).with("42", 8, "foobar").
      and_return(["\nbaz", 12])

    expect(renderer).to receive(:time_adjustment=).with(0.5)
    expect(renderer).to receive(:add_output).with("foo\n").ordered
    expect(renderer).to receive(:add_output).with("bar\n").ordered
    expect(renderer).to receive(:add_output).with("baz\n").ordered
    expect(renderer).to receive(:refresh).exactly(3).times
    expect(renderer).to receive(:finish).with(:done)

    expect(tracker).to receive(:sleep).with(1).exactly(2).times

    expect(tracker.track).to eq(:done)
  end

  it "treats error and cancelled states as finished states" do
    %w(error cancelled).each do |state|
      tracker = make_tracker("42", { :log_type => "foobar" })

      expect(@director).to receive(:get_task_state).with("42").
        and_return("queued", "processing", state)

      expect(@director).to receive(:get_task_output).with("42", 0, "foobar").
        and_return(["", nil], ["foo\nbar", 8])

      expect(@director).to receive(:get_task_output).with("42", 8, "foobar").
        and_return(["\nbaz", 12])

      expect(tracker).to receive(:sleep).with(1).exactly(2).times

      expect(tracker.track).to eq(state.to_sym)
    end
  end

  it "prompts for task cancel on interrupt (if in interactive mode)" do
    tracker = make_tracker("42", { :log_type => "foobar" })

    allow(tracker).to receive(:interactive?).and_return(true)

    expect(@director).to receive(:get_task_state).with("42").and_raise(Interrupt)
    expect(@director).to receive(:get_task_state).with("42").and_return("cancelled")
    expect(@director).to receive(:get_task_output).with("42", 0, "foobar").
      and_return(["", nil])

    expect(tracker).to receive(:ask).and_return("yes")
    expect(@director).to receive(:cancel_task).with("42")

    expect(tracker.track).to eq(:cancelled)
  end

  it "accepts alternate :renderer option" do
    tracker = make_tracker("42", {:renderer => "I'm a renderer"})
    expect(tracker.renderer).to eq("I'm a renderer")
  end

  it 'should set default success state to done' do
    tracker = make_tracker("42", { :log_type => "foobar"})
    expect(@director).to receive(:get_task_state).with("42").
                             and_return("done")

    expect(@director).to receive(:get_task_output).with("42", 0, "foobar").
                             and_return(["", nil])

    expect(tracker).to receive(:sleep).never

    expect(tracker.track).to eq(:done)
  end

  it 'should use task success state when set in options' do
    tracker = make_tracker("42", { :log_type => "foobar", :task_success_state => :queued })

    expect(@director).to receive(:get_task_state).with("42").
                             and_return("queued")

    expect(@director).to receive(:get_task_output).with("42", 0, "foobar").
                             and_return(["", nil])

    expect(tracker).to receive(:sleep).never

    expect(tracker.track).to eq(:queued)
  end


end
