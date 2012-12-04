require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::WardenCloud::Cloud do

  include Warden::Protocol
  include Bosh::WardenCloud::Helpers
  include Bosh::WardenCloud::Models

  attr_reader :logger

  before :each do
    @logger = Bosh::Clouds::Config.logger
    @disk_root = Dir.mktmpdir("warden-cpi-disk")

    options = {
      "disk" => {
        "root" => @disk_root,
        "fs" => "ext4",
      }
    }

    @cloud = Bosh::Clouds::Provider.create(:warden, options)

    [:connect, :disconnect].each do |op|
      Warden::Client.any_instance.stub(op) {} # no-op
    end

    vm = VM.new
    vm.container_id = '1234'
    vm.save
    @vm_id = vm.id.to_s

    disk = Disk.new
    disk.attached = false
    disk.image_path = "image_path"
    disk.save
    @disk_id = disk.id.to_s

    attached_disk = Disk.new
    attached_disk.attached = true
    attached_disk.device_num = 10
    attached_disk.vm = vm
    attached_disk.save
    @attached_disk_id = attached_disk.id.to_s
  end

  after :each do
    FileUtils.rm_rf @disk_root
    Disk.dataset.delete
  end

  context "attach_disk" do
    before :each do
      Warden::Client.any_instance.stub(:call) do |request|
        resp = nil

        if request.instance_of? RunRequest
          resp = RunResponse.new
          resp.stdout = "/dev/sda1\n"
        else
          raise "not supported"
        end

        resp
      end

    end

    it "can attach disk" do
      @cloud.delegate.should_receive(:sudo).with("losetup /dev/loop10 image_path")

      @cloud.attach_disk(@vm_id, @disk_id)

      disk = Disk[@disk_id.to_i]
      vm = VM[@vm_id.to_i]

      disk.attached.should == true
      disk.device_path.should == "/dev/sda1"
      disk.device_num.should_not == 0
      disk.vm.should == vm
    end

    it "raise error when trying to attach a disk that is already attached" do
      expect {
        @cloud.attach_disk(@vm_id, @attached_disk_id)
      }.to raise_error Bosh::Clouds::CloudError
    end

    it "raise error when trying to attach a disk to a non-existed vm" do
      expect {
        @cloud.attach_disk('vm_not_existed', @disk_id)
      }.to raise_error Bosh::Clouds::CloudError
    end
  end

  context "detach_disk" do
    before :each do
      Warden::Client.any_instance.stub(:call) do |request|
        resp = nil

        if request.instance_of? RunRequest
          resp = RunResponse.new
        else
          raise "not supported"
        end

        resp
      end

    end

    it "can detach disk" do
      @cloud.delegate.should_receive(:sudo).with("losetup -d /dev/loop10")

      @cloud.detach_disk(@vm_id, @attached_disk_id)

      disk = Disk[@attached_disk_id.to_i]
      disk.attached.should == false
      disk.device_path.should be_nil
      disk.device_num.should == 0
      disk.vm.should be_nil
    end

    it "raise error when trying to detach a disk that is not attached" do
      expect {
        @cloud.detach_disk(@vm_id, @disk_id)
      }.to raise_error Bosh::Clouds::CloudError
    end

    it "raise error when trying to detach a disk to a non-existed vm" do
      expect {
        @cloud.detach_disk('vm_not_existed', @attached_disk_id)
      }.to raise_error Bosh::Clouds::CloudError
    end
  end

  context "attach script" do
    before :each do
      @device_root = Dir.mktmpdir("warden-cpi-device")

      @device_prefix = File.join(@device_root, "sda")

      1.upto 5 do |i|
        FileUtils.touch("#{@device_prefix}#{i}")
      end
    end

    after :each do
      FileUtils.rm_rf @device_root
    end

    it "should provide the right device path" do
      script = attach_script(10, @device_prefix)
      device_file = sh("sudo bash -c '#{script}'").output.strip

      device_file.should == "#{@device_prefix}6"
      File.exist?(device_file).should be_true
    end
  end
end
