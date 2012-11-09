# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../../spec_helper", __FILE__)

describe Bosh::Director::Jobs::DeleteStemcell do

  describe "perform" do

    before(:each) do
      @cloud = mock("cloud")
      @blobstore = mock("blobstore")
      BD::Config.stub!(:cloud).and_return(@cloud)
      BD::Config.stub!(:blobstore).and_return(@blobstore)
    end

    it "should fail for unknown stemcells" do
      job = BD::Jobs::DeleteStemcell.new("test_stemcell", "test_version")
      job.should_receive(:with_stemcell_lock).
          with("test_stemcell", "test_version").and_yield
      lambda { job.perform }.should raise_exception(BD::StemcellNotFound)
    end

    it "should fail if CPI can't delete the stemcell" do
      BDM::Stemcell.make(:name => "test_stemcell",
                         :version => "test_version",
                         :cid => "stemcell_cid")

      @cloud.should_receive(:delete_stemcell).with("stemcell_cid").
          and_raise("error")

      job = BD::Jobs::DeleteStemcell.new("test_stemcell", "test_version")
      job.should_receive(:with_stemcell_lock).
          with("test_stemcell", "test_version").and_yield
      lambda { job.perform }.should raise_exception("error")
    end

    it "should fail if the deployments still reference this stemcell" do
      stemcell = BDM::Stemcell.make(:name => "test_stemcell",
                                    :version => "test_version",
                                    :cid => "stemcell_cid")

      deployment = BDM::Deployment.make
      deployment.add_stemcell(stemcell)

      job = BD::Jobs::DeleteStemcell.new("test_stemcell", "test_version")
      job.should_receive(:with_stemcell_lock).
          with("test_stemcell", "test_version").and_yield
      expect { job.perform }.to raise_exception(BD::StemcellInUse)
    end

    it "should delete the stemcell meta if the CPI deleted the stemcell" do
      stemcell = BDM::Stemcell.make(:name => "test_stemcell",
                                    :version => "test_version",
                                    :cid => "stemcell_cid")

      @cloud.should_receive(:delete_stemcell).with("stemcell_cid")

      job = BD::Jobs::DeleteStemcell.new("test_stemcell", "test_version")
      job.should_receive(:with_stemcell_lock).
          with("test_stemcell", "test_version").and_yield
      job.perform

      BDM::Stemcell[stemcell.id].should be_nil
    end

    it "should delete the associated compiled packages" do
      stemcell = BDM::Stemcell.make(:name => "test_stemcell",
                                    :version => "test_version",
                                    :cid => "stemcell_cid")

      package = BDM::Package.make
      compiled_package = BDM::CompiledPackage.make(
          :package => package, :stemcell => stemcell,
          :blobstore_id => "compiled-package-blb-id")

      @cloud.should_receive(:delete_stemcell).with("stemcell_cid")

      @blobstore.should_receive(:delete).with("compiled-package-blb-id")

      job = BD::Jobs::DeleteStemcell.new("test_stemcell", "test_version")
      job.should_receive(:with_stemcell_lock).
          with("test_stemcell", "test_version").and_yield
      job.perform

      BDM::Stemcell[stemcell.id].should be_nil
      BDM::CompiledPackage[compiled_package.id].should be_nil
    end
  end
end
