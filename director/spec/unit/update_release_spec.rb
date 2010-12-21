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
        @logger = Bosh::Director::Config.logger
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
      package_path = File.join(@release_dir, "packages", "test_package.tgz")
      File.open(package_path, "w") do |f|
        f.write(create_package({"test" => "test contents"}))
      end

      @blobstore.should_receive(:create).with(have_a_path_of(package_path)).and_return("blob_id")

      dependencies = Set.new
      package.should_receive(:blobstore_id=).with("blob_id")
      package.should_receive(:dependencies).and_return(dependencies)
      package.should_receive(:save!)

      @update_release_job.create_package({"name" => "test_package", "version" => "1.0", "sha1" => "some-sha",
                                          "dependencies" => ["foo_package", "bar_package"]})
      dependencies.should eql(Set.new(["foo_package", "bar_package"]))
    end

  end

  describe "resolve_package_dependencies" do

    before(:each) do
      @update_release_job = Bosh::Director::Jobs::UpdateRelease.new
      @update_release_job.instance_eval do
        @logger = Bosh::Director::Config.logger
      end
    end

    it "should normalize nil dependencies" do
      packages = [{"name" => "A"}, {"name" => "B", "dependencies" => ["A"]}]
      @update_release_job.resolve_package_dependencies(packages)
      packages.should eql([{"dependencies"=>[], "name"=>"A"}, {"dependencies"=>["A"], "name"=>"B"}])
    end

    it "should not allow cycles" do
      packages = [{"name" => "A", "dependencies" => ["B"]}, {"name" => "B", "dependencies" => ["A"]}]
      lambda {@update_release_job.resolve_package_dependencies(packages)}.should raise_exception
    end

    it "should resolve nested dependencies" do
      packages = [{"name" => "A", "dependencies" => ["B"]}, {"name" => "B", "dependencies" => ["C"]}, {"name" => "C"}]
      @update_release_job.resolve_package_dependencies(packages)
      packages.should eql([{"dependencies"=>["B", "C"], "name"=>"A"}, {"dependencies"=>["C"], "name"=>"B"},
                           {"dependencies"=>[], "name"=>"C"}])
    end

  end


end