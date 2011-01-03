require File.dirname(__FILE__) + '/../../spec_helper'

describe Bosh::Director::Jobs::DeleteStemcell do

  describe "perform" do

    before(:each) do
      @cloud = mock("cloud")
      Bosh::Director::Config.stub!(:cloud).and_return(@cloud)
    end

    it "should fail for unknown stemcells" do
      Bosh::Director::Models::Stemcell.stub!(:find).with(:name => "test_stemcell", :version => "test_version").
          and_return([])

      job = Bosh::Director::Jobs::DeleteStemcell.new("test_stemcell", "test_version")
      lambda { job.perform }.should raise_exception(Bosh::Director::StemcellNotFound)
    end

    it "should fail if CPI can't delete the stemcell" do
      stemcell = stub("stemcell")
      stemcell.stub!(:name).and_return("test_stemcell")
      stemcell.stub!(:version).and_return("test_version")
      stemcell.stub!(:cid).and_return("stemcell_cid")

      @cloud.should_receive(:delete_stemcell).with("stemcell_cid").and_raise("error")

      Bosh::Director::Models::Stemcell.stub!(:find).with(:name => "test_stemcell", :version => "test_version").
          and_return([stemcell])

      job = Bosh::Director::Jobs::DeleteStemcell.new("test_stemcell", "test_version")
      lambda { job.perform }.should raise_exception("error")
    end

    it "should delete the stemcell meta if the CPI deleted the stemcell" do
      stemcell = stub("stemcell")
      stemcell.stub!(:name).and_return("test_stemcell")
      stemcell.stub!(:version).and_return("test_version")
      stemcell.stub!(:cid).and_return("stemcell_cid")

      @cloud.should_receive(:delete_stemcell).with("stemcell_cid")

      Bosh::Director::Models::Stemcell.stub!(:find).with(:name => "test_stemcell", :version => "test_version").
          and_return([stemcell])

      stemcell.should_receive(:delete)

      job = Bosh::Director::Jobs::DeleteStemcell.new("test_stemcell", "test_version")
      job.perform
    end

  end

end
