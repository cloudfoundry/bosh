require File.dirname(__FILE__) + '/../spec_helper'

describe Bosh::Agent::State do

  before :each do
    @state_file = Tempfile.new("state").path
    FileUtils.rm(@state_file) # Only need path
  end

  def make_state(file)
    Bosh::Agent::State.new(file)
  end

  it "uses default state if no state exists yet" do
    state = make_state(@state_file)

    state.to_hash.should == {
      "deployment"   => "",
      "networks"     => { },
      "resource_pool"=> { }
    }
  end

  it "raises an exception on malformed state file" do
    lambda {
      state_file = Tempfile.new("malformed-state")
      state_file.write("test")
      state_file.close

      state = make_state(state_file.path)
      state.read
    }.should raise_error(Bosh::Agent::StateError, "Unexpected agent state format: expected Hash, got String")
  end

  it "returns the current state" do
    ts = Time.now
    Time.stub!(:now).and_return(ts)

    File.open(@state_file, "w") do |f|
      f.write(YAML.dump({ "a" => 1, "b" => 2}))
    end

    state = make_state(@state_file)
    state.to_hash.should == { "a" => 1, "b" => 2 }

    File.open(@state_file, "w") do |f|
      f.write(YAML.dump({ "a" => 2, "b" => 3}))
    end

    # Someone else re-wrote the file, we don't know about that
    state.to_hash.should == { "a" => 1, "b" => 2 }

    # Now we should know about the new contents
    state.write({ "a" => 2, "b" => 3})
    state.to_hash.should == { "a" => 2, "b" => 3 }
  end

  it "writes the state" do
    state = make_state(@state_file)

    ts  = Time.now
    ts2 = Time.now
    Time.stub!(:now).and_return(ts)

    state.write({ "a" => 1, "b" => 2})
    state.to_hash.should == { "a" => 1, "b" => 2 }

    Time.stub!(:now).and_return(ts2)

    state.write({ "a" => 1, "b" => 2})
    state.to_hash.should == { "a" => 1, "b" => 2 }
  end

  it "can be queried for particular state keys" do
    state = make_state(@state_file)
    state.write({"a" => 1, "b" => 2, "c" => { "d" => 3, "e" => 4}})

    state["a"].should == 1
    state["b"].should == 2
    state["c"].should == { "d" => 3, "e" => 4 }
  end

  it "retrieves the list of IPs from state" do
    state = make_state(@state_file)
    state.write({"networks" => { "a" => { "ip" => "10.0.0.1"}, "b" => { "ip" => "192.168.1.30"}}})

    state.ips.sort.should == ["10.0.0.1", "192.168.1.30"]
  end

end
