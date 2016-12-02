require File.expand_path('../../../spec_helper', __FILE__)

describe Bosh::Director::ProblemHandlers::MountInfoMismatch do

  def make_handler(disk_id, data = {})
    Bosh::Director::ProblemHandlers::MountInfoMismatch.new(disk_id, data)
  end

  let(:cloud) { Bosh::Director::Config.cloud }
  let(:cloud_factory) { instance_double(Bosh::Director::CloudFactory) }

  before(:each) do
    @agent = double('agent')

    @instance = Bosh::Director::Models::Instance.
      make(:job => 'mysql_node', :index => 3, availability_zone: 'az1')

    @disk = Bosh::Director::Models::PersistentDisk.
      make(:disk_cid => 'disk-cid', :instance_id => @instance.id,
           :size => 300, :active => false)

    @handler = make_handler(@disk.id, 'owner_vms' => []) # Not mounted
    allow(@handler).to receive(:cloud).and_return(@cloud)
    allow(@handler).to receive(:agent_client).with(@instance.credentials, @instance.agent_id).and_return(@agent)
    allow(Bosh::Director::CloudFactory).to receive(:new).and_return(cloud_factory)
  end

  it 'registers under inactive_disk type' do
    handler = Bosh::Director::ProblemHandlers::Base.create_by_type(:mount_info_mismatch, @disk.id, {})
    expect(handler).to be_kind_of(Bosh::Director::ProblemHandlers::MountInfoMismatch)
  end

  it 'has description' do
    expect(@handler.description).to match(/Inconsistent mount information/)
    expect(@handler.description).to match(/Not mounted in any VM/)
  end

  describe 'invalid states' do
    it 'is invalid if disk is gone' do
      @disk.destroy
      expect {
        make_handler(@disk.id)
      }.to raise_error("Disk '#{@disk.id}' is no longer in the database")
    end

    it 'is invalid if disk no longer has associated instance' do
      @instance.update(vm_cid: nil)
      expect {
        make_handler(@disk.id)
      }.to raise_error("Can't find corresponding vm-cid for disk 'disk-cid'")
    end

    describe 'reattach_disk' do
      it 'attaches disk' do
        expect(cloud).to receive(:attach_disk).with(@instance.vm_cid, @disk.disk_cid)
        expect(cloud).not_to receive(:reboot_vm)
        expect(cloud_factory).to receive(:for_availability_zone).with(@instance.availability_zone).and_return(cloud)
        expect(@agent).to receive(:mount_disk).with(@disk.disk_cid)
        @handler.apply_resolution(:reattach_disk)
      end

      it 'attaches disk and reboots the vm' do
        expect(cloud).to receive(:attach_disk).with(@instance.vm_cid, @disk.disk_cid)
        expect(cloud).to receive(:reboot_vm).with(@instance.vm_cid)
        expect(cloud_factory).to receive(:for_availability_zone).with(@instance.availability_zone).twice.and_return(cloud)
        expect(@agent).to receive(:wait_until_ready)
        expect(@agent).not_to receive(:mount_disk)
        @handler.apply_resolution(:reattach_disk_and_reboot)
      end
    end
  end
end
