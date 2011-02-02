require File.dirname(__FILE__) + '/../../spec_helper'

describe Bosh::Director::Jobs::DeleteStemcell do

  describe "perform" do

    before(:each) do
      @cloud = mock("cloud")
      @blobstore = mock("blobstore")
      Bosh::Director::Config.stub!(:cloud).and_return(@cloud)
      Bosh::Director::Config.stub!(:blobstore).and_return(@blobstore)
    end

    it "should fail for unknown stemcells" do
      Bosh::Director::Models::Stemcell.stub!(:find).with(:name => "test_stemcell", :version => "test_version").
          and_return([])

      lock = stub("lock")
      Bosh::Director::Lock.stub!(:new).with("lock:stemcells:test_stemcell:test_version", :timeout => 10).
          and_return(lock)
      lock.should_receive(:lock).and_yield

      job = Bosh::Director::Jobs::DeleteStemcell.new("test_stemcell", "test_version")
      lambda { job.perform }.should raise_exception(Bosh::Director::StemcellNotFound)
    end

    it "should fail if CPI can't delete the stemcell" do
      stemcell = stub("stemcell")
      stemcell.stub!(:name).and_return("test_stemcell")
      stemcell.stub!(:version).and_return("test_version")
      stemcell.stub!(:cid).and_return("stemcell_cid")
      stemcell.stub!(:deployments).and_return(Set.new)

      @cloud.should_receive(:delete_stemcell).with("stemcell_cid").and_raise("error")

      Bosh::Director::Models::Stemcell.stub!(:find).with(:name => "test_stemcell", :version => "test_version").
          and_return([stemcell])

      lock = stub("lock")
      Bosh::Director::Lock.stub!(:new).with("lock:stemcells:test_stemcell:test_version", :timeout => 10).
          and_return(lock)
      lock.should_receive(:lock).and_yield

      job = Bosh::Director::Jobs::DeleteStemcell.new("test_stemcell", "test_version")
      lambda { job.perform }.should raise_exception("error")
    end

    it "should fail if the deployments still reference this stemcell" do
      deployment = stub("deployment")
      deployment.stub!(:name).and_return("test_deployment")

      stemcell = stub("stemcell")
      stemcell.stub!(:name).and_return("test_stemcell")
      stemcell.stub!(:version).and_return("test_version")
      stemcell.stub!(:cid).and_return("stemcell_cid")
      stemcell.stub!(:deployments).and_return(Set.new([deployment]))

      Bosh::Director::Models::Stemcell.stub!(:find).with(:name => "test_stemcell", :version => "test_version").
          and_return([stemcell])

      lock = stub("lock")
      Bosh::Director::Lock.stub!(:new).with("lock:stemcells:test_stemcell:test_version", :timeout => 10).
          and_return(lock)
      lock.should_receive(:lock).and_yield

      job = Bosh::Director::Jobs::DeleteStemcell.new("test_stemcell", "test_version")
      lambda { job.perform }.should raise_exception(Bosh::Director::StemcellInUse)
    end

    it "should delete the stemcell meta if the CPI deleted the stemcell" do
      stemcell = stub("stemcell")
      stemcell.stub!(:id).and_return("33")
      stemcell.stub!(:name).and_return("test_stemcell")
      stemcell.stub!(:version).and_return("test_version")
      stemcell.stub!(:cid).and_return("stemcell_cid")
      stemcell.stub!(:deployments).and_return(Set.new)

      @cloud.should_receive(:delete_stemcell).with("stemcell_cid")

      Bosh::Director::Models::Stemcell.stub!(:find).with(:name => "test_stemcell", :version => "test_version").
          and_return([stemcell])

      Bosh::Director::Models::CompiledPackage.stub!(:find).with(:stemcell_id => "33").
          and_return([])

      stemcell.should_receive(:delete)

      lock = stub("lock")
      Bosh::Director::Lock.stub!(:new).with("lock:stemcells:test_stemcell:test_version", :timeout => 10).
          and_return(lock)
      lock.should_receive(:lock).and_yield

      job = Bosh::Director::Jobs::DeleteStemcell.new("test_stemcell", "test_version")
      job.perform
    end

    it "should delete the associated compiled packages" do
      stemcell = stub("stemcell")
      stemcell.stub!(:id).and_return("33")
      stemcell.stub!(:name).and_return("test_stemcell")
      stemcell.stub!(:version).and_return("test_version")
      stemcell.stub!(:cid).and_return("stemcell_cid")
      stemcell.stub!(:deployments).and_return(Set.new)

      package = stub("package")
      package.stub!(:name).and_return("test_package")
      package.stub!(:version).and_return("2")
      compiled_package = stub("compiled_package")
      compiled_package.stub!(:blobstore_id).and_return("compiled-package-blb-id")
      compiled_package.stub!(:package).and_return(package)

      @cloud.should_receive(:delete_stemcell).with("stemcell_cid")

      Bosh::Director::Models::Stemcell.stub!(:find).with(:name => "test_stemcell", :version => "test_version").
          and_return([stemcell])

      Bosh::Director::Models::CompiledPackage.stub!(:find).with(:stemcell_id => "33").
          and_return([compiled_package])

      @blobstore.should_receive(:delete).with("compiled-package-blb-id")
      compiled_package.should_receive(:delete)

      stemcell.should_receive(:delete)

      lock = stub("lock")
      Bosh::Director::Lock.stub!(:new).with("lock:stemcells:test_stemcell:test_version", :timeout => 10).
          and_return(lock)
      lock.should_receive(:lock).and_yield

      job = Bosh::Director::Jobs::DeleteStemcell.new("test_stemcell", "test_version")
      job.perform
    end

  end

end
