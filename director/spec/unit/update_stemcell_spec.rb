require File.dirname(__FILE__) + '/../spec_helper'

describe Bosh::Director::Jobs::UpdateStemcell do

  before(:each) do
    @task = mock("task")
    @cloud = mock("cloud")

    Bosh::Director::Config.stub!(:cloud).and_return(@cloud)
    Bosh::Director::Models::Task.stub!(:[]).with(1).and_return(@task)

    @path = Dir.mktmpdir("stemcell")
    FileUtils.mkdir_p(@path)

    @manifest_path = File.join(@path, "stemcell.MF")
    @image_path = File.join(@path, "image")

    manifest = {
      "name" => "jeos",
      "version" => 5,
      "cloud_properties" => {
        "ram" => "2gb"
      }
    }

    File.open(@manifest_path, "w") do |f|
      f.write(manifest.to_yaml)
    end

    File.open(@image_path, "w") do |f|
      f.write("image")
    end

  end

  after(:each) do
    FileUtils.rm_rf(@path)
  end

  it "should upload the stemcell" do
    @task.should_receive(:state=).with(:processing)
    @task.should_receive(:timestamp=)
    @task.should_receive(:save!)

    @task.should_receive(:state=).with(:done)
    @task.should_receive(:timestamp=)
    @task.should_receive(:save!)

    @cloud.should_receive(:create_stemcell).with(@image_path, {"ram" => "2gb"}).and_return("stemcell_cid")

    stemcell = mock("stemcell")
    stemcell.should_receive(:name=)
    stemcell.should_receive(:version=)
    stemcell.should_receive(:cid=)
    stemcell.should_receive(:save!)

    Bosh::Director::Models::Stemcell.stub!(:new).and_return(stemcell, nil)

    update_stemcell_job = Bosh::Director::Jobs::UpdateStemcell.new(1, @path)
    update_stemcell_job.perform
  end

  it "should cleanup the stemcell directory" do
    @task.should_receive(:state=).with(:processing)
    @task.should_receive(:timestamp=)
    @task.should_receive(:save!)

    @task.should_receive(:state=).with(:done)
    @task.should_receive(:timestamp=)
    @task.should_receive(:save!)

    @cloud.should_receive(:create_stemcell).with(@image_path, {"ram" => "2gb"}).and_return("stemcell_cid")

    stemcell = mock("stemcell")
    stemcell.should_receive(:name=)
    stemcell.should_receive(:version=)
    stemcell.should_receive(:cid=)
    stemcell.should_receive(:save!)

    Bosh::Director::Models::Stemcell.stub!(:new).and_return(stemcell, nil)

    update_stemcell_job = Bosh::Director::Jobs::UpdateStemcell.new(1, @path)
    update_stemcell_job.perform

    File.exist?(@path).should be_false
  end

end