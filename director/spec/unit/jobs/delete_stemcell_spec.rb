require File.expand_path("../../../spec_helper", __FILE__)

describe Bosh::Director::Jobs::DeleteStemcell do

  describe "perform" do

    before(:each) do
      @cloud = mock("cloud")
      @blobstore = mock("blobstore")
      Bosh::Director::Config.stub!(:cloud).and_return(@cloud)
      Bosh::Director::Config.stub!(:blobstore).and_return(@blobstore)
    end

    it "should fail for unknown stemcells" do
      lock = stub("lock")
      Bosh::Director::Lock.stub!(:new).with("lock:stemcells:test_stemcell:test_version", :timeout => 10).
          and_return(lock)
      lock.should_receive(:lock).and_yield

      job = Bosh::Director::Jobs::DeleteStemcell.new("test_stemcell", "test_version")
      lambda { job.perform }.should raise_exception(Bosh::Director::StemcellNotFound)
    end

    it "should fail if CPI can't delete the stemcell" do
      Bosh::Director::Models::Stemcell.make(:name => "test_stemcell",
                                            :version => "test_version",
                                            :cid => "stemcell_cid")

      @cloud.should_receive(:delete_stemcell).with("stemcell_cid").and_raise("error")

      lock = stub("lock")
      Bosh::Director::Lock.stub!(:new).with("lock:stemcells:test_stemcell:test_version", :timeout => 10).
          and_return(lock)
      lock.should_receive(:lock).and_yield

      job = Bosh::Director::Jobs::DeleteStemcell.new("test_stemcell", "test_version")
      lambda { job.perform }.should raise_exception("error")
    end

    it "should fail if the deployments still reference this stemcell" do
      stemcell = Bosh::Director::Models::Stemcell.make(:name => "test_stemcell",
                                                       :version => "test_version",
                                                       :cid => "stemcell_cid")

      deployment = Bosh::Director::Models::Deployment.make
      deployment.add_stemcell(stemcell)

      lock = stub("lock")
      Bosh::Director::Lock.stub!(:new).with("lock:stemcells:test_stemcell:test_version", :timeout => 10).
          and_return(lock)
      lock.should_receive(:lock).and_yield

      job = Bosh::Director::Jobs::DeleteStemcell.new("test_stemcell", "test_version")
      lambda { job.perform }.should raise_exception(Bosh::Director::StemcellInUse)
    end

    it "should delete the stemcell meta if the CPI deleted the stemcell" do
      stemcell = Bosh::Director::Models::Stemcell.make(:name => "test_stemcell",
                                                       :version => "test_version",
                                                       :cid => "stemcell_cid")

      @cloud.should_receive(:delete_stemcell).with("stemcell_cid")

      lock = stub("lock")
      Bosh::Director::Lock.stub!(:new).with("lock:stemcells:test_stemcell:test_version", :timeout => 10).
          and_return(lock)
      lock.should_receive(:lock).and_yield

      job = Bosh::Director::Jobs::DeleteStemcell.new("test_stemcell", "test_version")
      job.perform

      Bosh::Director::Models::Stemcell[stemcell.id].should be_nil
    end

    it "should delete the associated compiled packages" do
      stemcell = Bosh::Director::Models::Stemcell.make(:name => "test_stemcell",
                                                       :version => "test_version",
                                                       :cid => "stemcell_cid")

      package = Bosh::Director::Models::Package.make
      compiled_package = Bosh::Director::Models::CompiledPackage.make(:package => package,
                                                                      :stemcell => stemcell,
                                                                      :blobstore_id => "compiled-package-blb-id")

      @cloud.should_receive(:delete_stemcell).with("stemcell_cid")

      @blobstore.should_receive(:delete).with("compiled-package-blb-id")

      lock = stub("lock")
      Bosh::Director::Lock.stub!(:new).with("lock:stemcells:test_stemcell:test_version", :timeout => 10).
          and_return(lock)
      lock.should_receive(:lock).and_yield

      job = Bosh::Director::Jobs::DeleteStemcell.new("test_stemcell", "test_version")
      job.perform

      Bosh::Director::Models::Stemcell[stemcell.id].should be_nil
      Bosh::Director::Models::CompiledPackage[compiled_package.id].should be_nil
    end

  end

end
