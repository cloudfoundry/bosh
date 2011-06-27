require File.expand_path("../../../spec_helper", __FILE__)

describe Bosh::Director::Jobs::UpdateRelease do

  describe "perform" do

    before(:each) do
      @blobstore_client = mock("blobstore_client")
      Bosh::Director::Config.stub!(:blobstore).and_return(@blobstore_client)
    end

  end

  describe "create_package" do

    before(:each) do
      @release = release = Bosh::Director::Models::Release.make
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

    after(:each) do
      FileUtils.rm_rf(@release_dir)
    end

    it "should create simple packages" do
      FileUtils.mkdir_p(File.join(@release_dir, "packages"))
      package_path = File.join(@release_dir, "packages", "test_package.tgz")
      File.open(package_path, "w") do |f|
        f.write(create_package({"test" => "test contents"}))
      end

      @blobstore.should_receive(:create).with(have_a_path_of(package_path)).and_return("blob_id")

      @update_release_job.create_package({"name" => "test_package", "version" => "1.0", "sha1" => "some-sha",
                                          "dependencies" => ["foo_package", "bar_package"]})

      package = Bosh::Director::Models::Package[:name => "test_package", :version => "1.0"]
      package.should_not be_nil
      package.name.should == "test_package"
      package.version.should == "1.0"
      package.release.should == @release
      package.sha1.should == "some-sha"
      package.blobstore_id.should == "blob_id"
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
      packages.should eql([{"dependencies" => [], "name" => "A"}, {"dependencies" => ["A"], "name" => "B"}])
    end

    it "should not allow cycles" do
      packages = [{"name" => "A", "dependencies" => ["B"]}, {"name" => "B", "dependencies" => ["A"]}]
      lambda {@update_release_job.resolve_package_dependencies(packages)}.should raise_exception
    end

    it "should resolve nested dependencies" do
      packages = [{"name" => "A", "dependencies" => ["B"]}, {"name" => "B", "dependencies" => ["C"]}, {"name" => "C"}]
      @update_release_job.resolve_package_dependencies(packages)
      packages.should eql([{"dependencies" => ["B", "C"], "name" => "A"}, {"dependencies" => ["C"], "name" => "B"},
                           {"dependencies" => [], "name" => "C"}])
    end

  end


end
