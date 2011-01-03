require 'spec_helper'
require 'fileutils'

describe Bosh::Cli::Cache do

  before :each do
    @cache_dir = File.join(Dir.mktmpdir, "bosh_cache")
  end

  after :each do
    FileUtils.rm_rf(@cache_dir)
  end

  it "whines if cache directory turned out to be a file" do
    FileUtils.touch(@cache_dir)
    lambda {
      Bosh::Cli::Cache.new(@cache_dir)
    }.should raise_error(Bosh::Cli::CacheDirectoryError)
  end

  it "creates cache directory" do
    File.directory?(@cache_dir).should be_false
    cache = Bosh::Cli::Cache.new(@cache_dir)
    File.directory?(@cache_dir).should be_true    
  end

  it "performs read/write in an expected way" do
    cache = Bosh::Cli::Cache.new(@cache_dir)
    cache.read("foo").should be_nil
    cache.write("foo", "12321")
    cache.read("foo").should == "12321"    
  end
  
end
