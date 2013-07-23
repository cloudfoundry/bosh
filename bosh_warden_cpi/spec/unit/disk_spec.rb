require "spec_helper"

describe Bosh::WardenCloud::Cloud do
  before do
    [:connect, :disconnect].each do |op|
      Warden::Client.any_instance.stub(op) do
        # no-op
      end
    end
    @logger = Bosh::Clouds::Config.logger
    @disk_root = Dir.mktmpdir("warden-cpi-disk")
    @stemcell_root = Dir.mktmpdir("warden-cpi-stemcell")
    options = {
        "disk" => {
            "root" => @disk_root,
            "fs" => "ext4",
        },
        "stemcell" => {
            "root" => @stemcell_root,
        },
    }
    @cloud = Bosh::Clouds::Provider.create(:warden, options)

  end

  after { Bosh::WardenCloud::Models::Disk.dataset.delete }

  def mock_create_disk
    zero_exit_status = mock("Process::Status", :exit_status => 0)
    Bosh::Exec.should_receive(:sh).with(%r!\bmkfs -t ext4\b!, :yield => :on_false).ordered.and_return(zero_exit_status)
  end

  def attach_disk(disk_id)
    disk = Bosh::WardenCloud::Models::Disk[disk_id.to_i]
    disk.attached = true
    disk.save
  end

  context "create_disk" do
    it "can create disk" do
      mock_create_disk

      disk_id  = @cloud.create_disk(1, nil)

      Dir.chdir(@disk_root) do
        image = image_file(disk_id)

        Dir.glob("*").should have(1).items
        Dir.glob("*").should include(image)

        File.stat(image).size.should == 1 << 20
      end
    end

    it "should raise error if size is 0" do
      expect {
        @cloud.create_disk(0, nil)
      }.to raise_error ArgumentError
    end

    it "should raise error if size is smaller than 0" do
      expect {
        @cloud.create_disk(-1, nil)
      }.to raise_error ArgumentError
    end

    it "should clean up when create disk failed" do
      @cloud.delegate.stub(:image_path) { "/path/not/exist" }

      expect {
        @cloud.create_disk(1, nil)
      }.to raise_error

      Bosh::WardenCloud::Models::Disk.dataset.all.size.should == 0
      Dir.chdir(@disk_root) do
        Dir.glob("*").should be_empty
      end
    end
  end

  context "delete_disk" do
    before :each do
      mock_create_disk

      @disk_id = @cloud.create_disk(1, nil)
    end

    it "can delete disk" do
      Dir.chdir(@disk_root) do
        Dir.glob("*").should have(1).items
        Dir.glob("*").should include(image_file(@disk_id))

        ret = @cloud.delete_disk(@disk_id)

        Dir.glob("*").should be_empty
        ret.should be_nil
      end
    end

    it "should raise error when trying to delete non-existed disk" do
      expect {
        @cloud.delete_disk("12345")
      }.to raise_error Bosh::Clouds::CloudError
    end

    it "should raise error when disk is attached" do
      attach_disk(@disk_id)

      expect {
        @cloud.delete_disk(@disk_id)
      }.to raise_error Bosh::Clouds::CloudError
    end
  end
end
