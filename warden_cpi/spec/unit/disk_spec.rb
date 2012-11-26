require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::WardenCloud::Cloud do

  before :each do
    @disk_root = Dir.mktmpdir("warden-cpi-disk")

    options = {
      "disk" => {
        "root" => @disk_root,
        "fs" => "ext4",
      }
    }

    @cloud = Bosh::Clouds::Provider.create(:warden, options)
  end

  context "successful cases" do

    it "can create disk" do
      disk_id  = @cloud.create_disk(1, nil)

      Dir.chdir(@disk_root) do
        Dir.glob("*").should have(1).items
        Dir.glob("*").should include("#{disk_id}.img")
        # TODO the image should be exactly 1MB
      end
    end

    it "can delete disk" do
      Dir.chdir(@disk_root) do
        disk_id  = @cloud.create_disk(1, nil)

        Dir.glob("*").should have(1).items
        Dir.glob("*").should include("#{disk_id}.img")

        ret = @cloud.delete_disk(disk_id)

        Dir.glob("*").should be_empty
        ret.should be_nil
      end
    end
  end

  context "failed cases" do
    it "should raise error if size is 0" do
      expect {
        @cloud.create_disk(0, nil)
      }.to raise_error Bosh::Clouds::CloudError
    end

    it "should raise error if size is smaller than 0" do
      expect {
        @cloud.create_disk(-1, nil)
      }.to raise_error Bosh::Clouds::CloudError
    end

    it "should raise error when trying to delete non-existed disk" do
      expect {
        @cloud.delete_disk("12345")
      }.to raise_error Bosh::Clouds::CloudError
    end

    it "should raise error when disk is attached" do
      disk_id = @cloud.create_disk(1, nil)

      attach_disk(disk_id)

      expect {
        @cloud.delete_disk(disk_id)
      }.to raise_error Bosh::Clouds::CloudError
    end
  end
end

def attach_disk(disk_id)
  disk = Bosh::WardenCloud::Models::Disk[disk_id.to_i]
  disk.attached = true

  disk.save
end
