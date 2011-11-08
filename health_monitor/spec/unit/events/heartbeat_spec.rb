require 'spec_helper'

describe Bhm::Events::Heartbeat do

  before :each do
    @ts = 1320196099
  end

  def make_heartbeat(attrs = {})
    defaults = {
      :id => 1,
      :timestamp => @ts,
      :deployment => "oleg-cloud",
      :agent_id => "deadbeef",
      :job => "mysql_node",
      :index => "0",
      :job_state => "running",
      :vitals => {
        "load" => [0.2, 0.3, 0.6],
        "cpu" => { "user" => 22.3, "sys" => 23.4, "wait" => 33.22 },
        "mem" => { "percent" => 32.2, "kb" => 512031 },
        "swap" => { "percent" => 32.6, "kb" => 231312 },
        "disk" => {
          "system" => { "percent" => 74 },
          "ephemeral" => { "percent" => 33 },
          "persistent" => { "percent" => 97 },
        }
      }
    }
    Bhm::Events::Heartbeat.new(defaults.merge(attrs))
  end

  it "supports attributes validation" do
    make_heartbeat.should be_valid
    make_heartbeat.kind.should == :heartbeat

    make_heartbeat(:id => nil).should_not be_valid
    make_heartbeat(:timestamp => nil).should_not be_valid

    bad_heartbeat = make_heartbeat(:id => nil, :timestamp => nil)
    bad_heartbeat.should_not be_valid
    bad_heartbeat.error_message.should == "id is missing, timestamp is missing"
  end

  it "has short description" do
    make_heartbeat.short_description.should == "Heartbeat from mysql_node/0 (deadbeef) @ 2011-11-02 01:08:19 UTC"
  end

  it "has hash representation" do
    make_heartbeat.to_hash.should == {
      :kind => "heartbeat",
      :id => 1,
      :timestamp => @ts,
      :deployment => "oleg-cloud",
      :agent_id => "deadbeef",
      :job => "mysql_node",
      :index => "0",
      :job_state => "running",
      :vitals => {
        "load" => [0.2, 0.3, 0.6],
        "cpu" => { "user" => 22.3, "sys" => 23.4, "wait" => 33.22 },
        "mem" => { "percent" => 32.2, "kb" => 512031 },
        "swap" => { "percent" => 32.6, "kb" => 231312 },
        "disk" => {
          "system" => { "percent" => 74 },
          "ephemeral" => { "percent" => 33 },
          "persistent" => { "percent" => 97 },
        }
      }
    }
  end

  it "has plain text representation" do
    hb = make_heartbeat
    hb.to_plain_text.should == hb.short_description
  end

  it "has json representation" do
    hb = make_heartbeat
    hb.to_json.should == Yajl::Encoder.encode(hb.to_hash)
  end

  it "has string representation" do
    hb = make_heartbeat
    hb.to_s.should == hb.short_description
  end

  it "has metrics" do
    hb = make_heartbeat
    metrics = hb.metrics.inject({}) do |h, m|
      m.should be_kind_of(Bhm::Metric)
      m.tags.should == { "job" => "mysql_node", "index" => "0", "role" => "service" }
      h[m.name] = m.value; h
    end

    metrics["system.load.1m"].should == 0.2
    metrics["system.cpu.user"].should == 22.3
    metrics["system.cpu.sys"].should == 23.4
    metrics["system.cpu.wait"].should == 33.22
    metrics["system.mem.percent"].should == 32.2
    metrics["system.mem.kb"].should == 512031
    metrics["system.swap.percent"].should == 32.6
    metrics["system.swap.kb"].should == 231312
    metrics["system.disk.system.percent"].should == 74
    metrics["system.disk.ephemeral.percent"].should == 33
    metrics["system.disk.persistent.percent"].should == 97
    metrics["system.healthy"].should == 1
  end

end
