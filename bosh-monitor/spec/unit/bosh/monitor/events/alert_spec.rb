require "spec_helper"

describe Bhm::Events::Alert do

  it "supports attributes validation" do
    make_alert.should be_valid
    make_alert.kind.should == :alert

    make_alert(:id => nil).should_not be_valid
    make_alert(:severity => nil).should_not be_valid
    make_alert(:severity => -2).should_not be_valid
    make_alert(:title => nil).should_not be_valid
    make_alert(:created_at => nil).should_not be_valid
    make_alert(:created_at => "foobar").should_not be_valid

    test_alert = make_alert(:id => nil, :severity => -3, :created_at => "foobar")
    test_alert.validate
    test_alert.error_message.should == "id is missing, severity is invalid (non-negative integer expected), created_at is invalid UNIX timestamp"
  end

  it "has short description" do
    make_alert.short_description.should == "Severity 2: mysql_node/0 Test Alert"
  end

  it "has hash representation" do
    ts = Time.now
    make_alert(:created_at => ts.to_i).to_hash.should == {
      :kind       => "alert",
      :id         => 1,
      :severity   => 2,
      :title      => "Test Alert",
      :summary    => "Everything is down",
      :source     => "mysql_node/0",
      :created_at => ts.to_i
    }
  end

  it "has plain text representation" do
    ts = Time.now
    make_alert(:created_at => ts.to_i).to_plain_text.should == <<-EOS.gsub(/^\s*/, "")
      mysql_node/0
      Test Alert
      Severity: 2
      Summary: Everything is down
      Time: #{ts.utc}
    EOS
  end

  it "has json representation" do
    alert = make_alert
    alert.to_json.should == Yajl::Encoder.encode(alert.to_hash)
  end

  it "has string representation" do
    ts = 1320196099
    alert = make_alert(:created_at => ts)
    alert.to_s.should == "Alert @ 2011-11-02 01:08:19 UTC, severity 2: Everything is down"
  end

  it "has metrics" do
    make_alert.metrics.should == []
  end

end
