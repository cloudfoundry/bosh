require File.dirname(__FILE__) + '/../spec_helper'

describe Bosh::Director::Jobs::UpdateRelease do

  def gzip(string)
    result = StringIO.new
    zio = Zlib::GzipWriter.new(result)
    zio.mtime = 1
    zio.write(string)
    zio.close
    result.string
  end

  def create_release(name, version, jobs, packages)
    io = StringIO.new

    manifest = {
      "name" => name,
      "version" => version
    }

    Archive::Tar::Minitar::Writer.open(io) do |tar|
      tar.add_file("release.MF", {:mode => "0644", :mtime => 0}) {|os, _| os.write(manifest.to_yaml)}
      tar.mkdir("packages", {:mode => "0755"})
      packages.each do |package|
        tar.add_file("packages/#{package[:name]}.tgz", {:mode => "0644", :mtime => 0}) {|os, _| os.write("package")}
      end
      tar.mkdir("jobs", {:mode => "0755"})
      jobs.each do |job|
        tar.add_file("jobs/#{job[:name]}.tgz", {:mode => "0644", :mtime => 0}) {|os, _| os.write("job")}
      end
    end

    io.close
    gzip(io.string)
  end

  def create_package(files)
    io = StringIO.new

    Archive::Tar::Minitar::Writer.open(io) do |tar|
      files.each do |key, value|
        tar.add_file(key, {:mode => "0644", :mtime => 0}) {|os, _| os.write(value)}
      end
    end

    io.close
    gzip(io.string)
  end

  describe "perform" do

    before(:each) do
      @task = mock("task")
      @blobstore_client = mock("blobstore_client")

      Bosh::Director::Models::Task.stub!(:[]).with(1).and_return(@task)
      @task.should_receive(:output).and_return(STDOUT)

      Bosh::Director::Config.stub!(:blobstore).and_return(@blobstore_client)
    end

  end

  describe "create_package" do

    before(:each) do
      @release = release = mock("release")
      @release_dir = release_dir = Dir.mktmpdir("release_dir")
      @blobstore = blobstore = mock("blobstore_client")

      @update_release_job = Bosh::Director::Jobs::UpdateRelease.new
      @update_release_job.instance_eval do
        @logger = Logger.new(STDOUT)
        @release = release
        @tmp_release_dir = release_dir
        @blobstore = blobstore
      end
    end

    it "should create simple packages" do
      package = stub("package")
      package.stub!(:name).and_return("test_package")

      Bosh::Director::Models::Package.stub!(:new).with(:release => @release, :name => "test_package", :version => "1.0",
                                                       :sha1    => "some-sha").and_return(package)
      FileUtils.mkdir_p(File.join(@release_dir, "packages"))
      File.open(File.join(@release_dir, "packages", "test_package.tgz"), "w") do |f|
        f.write(create_package({"test" => "test contents"}))
      end

      @blobstore.should_receive(:create).with()

      @update_release_job.create_package({"name" => "test_package", "version" => "1.0", "sha1" => "some-sha"})
    end

  end

end