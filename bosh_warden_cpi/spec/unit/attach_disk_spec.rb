require "spec_helper"

describe Bosh::WardenCloud::Cloud do
  include Bosh::WardenCloud::Helpers
  attr_reader :logger

  before :each do
    @logger = Bosh::Clouds::Config.logger
    @disk_root = Dir.mktmpdir("warden-cpi-disk")

    options = {
      "disk" => {
        "root" => @disk_root,
        "fs" => "ext4",
      },
      "stemcell" => {
        "root" => @disk_root,
      },
    }
    @cloud = Bosh::Clouds::Provider.create(:warden, options)

    [:connect, :disconnect].each do |op|
      Warden::Client.any_instance.stub(op) {} # no-op
    end

    vm = Bosh::WardenCloud::Models::VM.new
    vm.container_id = "1234"
    vm.save
    @vm_id = vm.id.to_s

    disk = Bosh::WardenCloud::Models::Disk.new
    disk.attached = false
    disk.image_path = "image_path"
    disk.save
    @disk_id = disk.id.to_s

    attached_disk = Bosh::WardenCloud::Models::Disk.new
    attached_disk.attached = true
    attached_disk.device_num = 10
    attached_disk.vm = vm
    attached_disk.save
    @attached_disk_id = attached_disk.id.to_s

    @cloud.delegate.stub(:get_agent_env).and_return({"disks" => {"persistent" => {}}})
    @cloud.delegate.stub(:set_agent_env) {}
  end

  after do
    FileUtils.rm_rf @disk_root
    Bosh::WardenCloud::Models::Disk.dataset.delete
  end

  def mock_attach_sudos (cmd, success = true, times = 1)
    zero_exit_status = mock("Process::Status", :exit_status => 0)
    result = mock("Result", :success? => success)
    Bosh::Exec.should_receive(:sh).exactly(times).times.with(%r!sudo -n #{cmd}.*!, :yield => :on_false).and_yield(result).and_return(zero_exit_status)
  end

  context "attach_disk" do
    before :each do
      Warden::Client.any_instance.stub(:call) do |request|
        resp = nil

        if request.instance_of?(Warden::Protocol::RunRequest)
          resp = Warden::Protocol::RunResponse.new
          resp.stdout = "/dev/sda1\n"
        else
          raise "not supported"
        end

        resp
      end

    end

    it "can attach disk" do
      mock_attach_sudos("mount")
      @cloud.attach_disk(@vm_id, @disk_id)

      disk = Bosh::WardenCloud::Models::Disk[@disk_id.to_i]
      vm = Bosh::WardenCloud::Models::VM[@vm_id.to_i]

      disk.attached.should == true
      disk.device_path.should == File.join(@disk_root, 'bind_mount_points', @vm_id, @disk_id )
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
        @cloud.attach_disk("vm_not_existed", @disk_id)
      }.to raise_error Bosh::Clouds::CloudError
    end
  end

  context "detach_disk" do
    before do
      Warden::Client.any_instance.stub(:call) do |request|
        resp = nil

        if request.instance_of?(Warden::Protocol::RunRequest)
          resp = Warden::Protocol::RunResponse.new
        else
          raise "not supported"
        end

        resp
      end

    end

    it "can detach disk" do
      mock_attach_sudos("umount")
      @cloud.detach_disk(@vm_id, @attached_disk_id)

      disk = Bosh::WardenCloud::Models::Disk[@attached_disk_id.to_i]
      disk.attached.should == false
      disk.device_path.should be_nil
      disk.vm.should be_nil
    end

    it 'will retry umount for detach disk' do
      mock_attach_sudos("umount", false, Bosh::WardenCloud::Cloud::UMOUNT_GUARD_RETRIES + 1)
      expect {
        @cloud.detach_disk(@vm_id, @attached_disk_id)
      }. to raise_error
    end

    it "raise error when trying to detach a disk that is not attached" do
      expect {
        @cloud.detach_disk(@vm_id, @disk_id)
      }.to raise_error Bosh::Clouds::CloudError
    end

    it "raise error when trying to detach a disk to a non-existed vm" do
      expect {
        @cloud.detach_disk("vm_not_existed", @attached_disk_id)
      }.to raise_error Bosh::Clouds::CloudError
    end
  end

  context "attach script" do
    before do
      @device_root = Dir.mktmpdir("warden-cpi-device")

      @device_prefix = File.join(@device_root, "sd")

      %w[a b c].each do |i|
        FileUtils.touch("#{@device_prefix}#{i}")
        FileUtils.touch("#{@device_prefix}#{i}1")
      end
    end

    after do
      FileUtils.rm_rf @device_root
    end

    it "should provide the right device path" do
      pending "mknod operation should be done outside of unit test"
      script = attach_script(10, @device_prefix)
      device_file = sh("sudo bash -c '#{script}'").output.strip

      device_file.should == "#{@device_prefix}d"
      File.exist?(partition_path(device_file)).should be_true
    end
  end
end
