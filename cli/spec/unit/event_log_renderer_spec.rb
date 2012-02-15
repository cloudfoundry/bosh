# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe Bosh::Cli::EventLogRenderer do

  def make_event(stage, task, index, total, state = "started", tags = [], progress = 0)
    event = {
      "time"  => Time.now.to_i,
      "stage" => stage,
      "task"  => task,
      "index" => index,
      "total" => total,
      "state" => state,
      "tags"  => tags,
      "progress" => progress
    }
    JSON.generate(event)
  end

  def make_renderer(*args)
    Bosh::Cli::EventLogRenderer.new(*args)
  end

  it "allows adding events" do
    renderer = make_renderer
    renderer.add_event(make_event("Preparing", "Binding release", 1, 9, "started"))
    renderer.add_event(make_event("Preparing", "Binding existing deployment", 2, 9, "started"))
    renderer.events_count.should == 2
  end

  it "silently ignores malformed events" do
    renderer = make_renderer
    renderer.add_event(make_event(nil, "Binding release", 1, 9, nil, []))
    renderer.add_event(make_event("Preparing", "Binding existing deployment", 2, nil, nil))
    renderer.add_event(JSON.generate("a" => "b"))
    renderer.events_count.should == 0
  end

  it "sets current stage based on the most recent event but ignores events from non-current stages" do
    renderer = make_renderer
    renderer.add_event(make_event("Preparing", "Binding release", 1, 9))
    renderer.current_stage.should == "Preparing"
    renderer.add_event(make_event("Preparing", "Binding existing deployment", 2, 9))
    renderer.current_stage.should == "Preparing"
    renderer.add_event(make_event("Updating resource pool", "Deleting outdated VM", 1, 5))
    renderer.current_stage.should == "Updating resource pool"
    renderer.events_count.should == 3
    renderer.add_event(make_event("Preparing", "Some additional stuff", 3, 9))
    renderer.current_stage.should == "Updating resource pool"
    renderer.events_count.should == 3
    renderer.add_event(make_event("Updating job router", "Canary update", 1, 1))
    renderer.current_stage.should == "Updating job router"
    renderer.events_count.should == 4
  end

  it "can render event log with progress bar" do
    buf = StringIO.new
    Bosh::Cli::Config.output = buf

    renderer = make_renderer
    renderer.add_event(make_event("Preparing", "Binding release", 1, 9))

    lines = renderer.render.split("\n")

    lines.count.should == 3
    lines[1].should == "Preparing"
    lines[2].should =~ /Binding release/
    lines[2].should =~ /\|\s+\| 0\/9/

    renderer.add_event(make_event("Preparing", "Moving stuff", 2, 9))

    lines = renderer.render.split("\n")
    lines.count.should == 1
    lines[0].should =~ /Binding release/
    lines[0].should =~ /\|\s+\| 0\/9/

    renderer.add_event(make_event("Preparing", "Moving stuff", 2, 9, "finished"))

    lines = renderer.render.split("\n")
    lines.count.should == 2
    lines[0].should =~ /moving stuff/
    lines[1].should =~ /Binding release/
    lines[1].should =~ /\|o+\s+\| 1\/9/

    # throwing in out-of-order event
    renderer.add_event(make_event("Preparing", "Binding release", 1, 9, "finished"))

    (3..9).each do |i|
      renderer.add_event(make_event("Preparing", "event #{i}", i, 9))
      renderer.add_event(make_event("Preparing", "event #{i}", i, 9, "finished"))
    end

    lines = renderer.render.split("\n")
    lines.count.should == 9
    lines[-1].should =~ /\|o+\| 9\/9/

    renderer.add_event(make_event("Updating", "prepare update", 1, 2, "started", ["stuff", "thing"]))

    lines = renderer.render.split("\n")
    lines.count.should == 4

    lines[0].should =~ /Done/
    lines[0].should =~ /9\/9/
    lines[1].should == ""
    lines[2].should == "Updating %s" % [ "stuff, thing".green ]
    lines[3].should =~ /0\/2/

    lines = renderer.finish(:done).split("\n")
    lines[0].should =~ /Done/
    lines[0].should =~ /2\/2/
  end

  it "renders erorr state properly" do
    buf = StringIO.new
    Bosh::Cli::Config.output = buf

    renderer = make_renderer
    renderer.add_event(make_event("Preparing", "Binding release", 1, 9))
    renderer.add_event(make_event("Preparing", "Moving stuff", 2, 9))
    renderer.add_event(make_event("Preparing", "Moving stuff", 2, 9, "finished"))
    renderer.add_event(make_event("Updating", "prepare update", 1, 2, "started", ["stuff", "thing"]))

    lines = renderer.finish(:error).split("\n")
    lines[-1].should =~ /Error/
    lines[-1].should =~ /0\/2/
  end

  it "supports tracking individual tasks progress" do
    renderer = make_renderer
    renderer.add_event(make_event("Preparing", "Binding release", 1, 2, "started", [], 0))
    renderer.add_event(make_event("Preparing", "Binding release", 1, 2, "in_progress", [], 25))

    lines = renderer.render.split("\n")

    lines[1].should =~ /Preparing/
    lines[2].should =~ /\|o+\s+\| 0\/2/
    lines[2].should =~ /Binding release/

    renderer.add_event(make_event("Preparing", "Binding release", 1, 2, "in_progress", [], 50))

    lines = renderer.render.split("\n")

    lines[0].should =~ /\|o+\s+\| 0\/2/
    lines[0].should =~ /Binding release/

    renderer.add_event(make_event("Preparing", "Binding release", 1, 2, "finished", []))

    lines = renderer.render.split("\n")
    lines[1].should_not =~ /Binding release/
    lines[1].should =~ /\|o+\s+\| 1\/2/
  end

end
