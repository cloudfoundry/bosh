require 'spec_helper'

describe VCAP::Micro::DNS do

  before(:each) do
    @dns = VCAP::Micro::DNS.new("1.2.3.4", "martin.cloudfoundry.me")
  end

  it "should generate template files" do
    @dns.should_receive(:execute).exactly(1).times
    dest = "tmp"
    FileUtils.mkdir_p(dest)

    @dns.generate(dest)
    VCAP::Micro::DNS::FILES.each do |src, dst|
      "#{dest}/#{dst}".should be_same_file_as("spec/assets/#{dst}")
    end
  end

end