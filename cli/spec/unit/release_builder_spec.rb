require "spec_helper"
require "fileutils"

describe Bosh::Cli::ReleaseBuilder do

  before(:each) do
    @work_dir = Dir.mktmpdir
    FileUtils.mkdir(File.join(@work_dir, "releases"))
  end

  def new_builder
    Bosh::Cli::ReleaseBuilder.new(@work_dir, [], [])
  end

  it "uses version 1 if no previous releases have been created" do
    new_builder.version.should == 1
  end

end
