require "spec_helper"

describe String do

  it "can tell valid bosh identifiers from invalid" do
    %w(ruby ruby-1.8.7 mysql-2.3.5-alpha Apache_2.3).each do |id|
      id.bosh_valid_id?.should be_true
    end

    ["ruby 1.8", "ruby-1.8@b29", "#!@", "db/2", "ruby(1.8)"].each do |id|
      id.bosh_valid_id?.should be_false
    end
  end
  
end
