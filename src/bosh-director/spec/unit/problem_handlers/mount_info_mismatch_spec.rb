require File.expand_path('../../../spec_helper', __FILE__)

describe Bosh::Director::ProblemHandlers::MountInfoMismatch do

  def make_handler(disk_id, data = {})
    Bosh::Director::ProblemHandlers::MountInfoMismatch.new(disk_id, data)
  end

  let(:cloud) { instance_double(Bosh::Clouds::ExternalCpi) }
  let(:az_cloud_factory) { instance_double(Bosh::Director::AZCloudFactory) }
  let(:base_cloud_factory) { instance_double(Bosh::Director::CloudFactory) }
  let(:manifest) do
    { 'tags' => { 'mytag' => 'myvalue' } }
  end

  before(:each) do
    @agent = double('agent')

    deployment = FactoryBot.create(:models_deployment, name: 'my-deployment', manifest: YAML.dump(manifest))
    FactoryBot.create(:models_variable_set, deployment_id: deployment.id)

    @instance = Bosh::Director::Models::Instance.
      make(:job => 'mysql_node', :index => 3, availability_zone: 'az1')
    @vm = Bosh::Director::Models::Vm.make(instance_id: @instance.id, cpi: 'cpi1', stemcell_api_version: 25)

    @instance.active_vm = @vm
    @instance.save
    deployment.add_instance(@instance)

    @disk = Bosh::Director::Models::PersistentDisk.
      make(:disk_cid => 'disk-cid', :instance_id => @instance.id,
           :size => 300, :active => false)

    @handler = make_handler(@disk.id, 'owner_vms' => []) # Not mounted
    allow(@handler).to receive(:cloud).and_return(@cloud)
    allow(@handler).to receive(:agent_client).with(@instance.agent_id, @instance.name).and_return(@agent)
    allow(Bosh::Director::AZCloudFactory).to receive(:create_with_latest_configs).and_return(az_cloud_factory)
    allow(Bosh::Director::AZCloudFactory).to receive(:create_from_deployment).and_return(az_cloud_factory)
    allow(Bosh::Director::CloudFactory).to receive(:create).and_return(base_cloud_factory)
    allow(az_cloud_factory).to receive(:get_for_az).with('az1', 25).and_return(cloud)
  end

  it 'registers under inactive_disk type' do
    handler = Bosh::Director::ProblemHandlers::Base.create_by_type(:mount_info_mismatch, @disk.id, {})
    expect(handler).to be_kind_of(Bosh::Director::ProblemHandlers::MountInfoMismatch)
  end

  it 'is not an instance problem' do
    expect(@handler.instance_problem?).to be_falsey
  end

  it 'has description' do
    expect(@handler.description).to match(/Inconsistent mount information/)
    expect(@handler.description).to match(/Not mounted in any VM/)
  end

  describe 'instance group' do
    it 'returns the job of the instance of the disk' do
      expect(@handler.instance_group).to eq('mysql_node')
    end
  end

  describe 'invalid states' do
    it 'is invalid if disk is gone' do
      @disk.destroy
      expect {
        make_handler(@disk.id)
      }.to raise_error("Disk '#{@disk.id}' is no longer in the database")
    end

    it 'is invalid if disk no longer has associated instance' do
      @instance.active_vm = nil
      expect {
        make_handler(@disk.id)
      }.to raise_error("Can't find corresponding vm-cid for disk 'disk-cid'")
    end

    describe 'reattach_disk' do
      let(:cloud_for_update_metadata) { instance_double(Bosh::Clouds::ExternalCpi) }

      context 'cloud API V1' do
        it 'attaches disk' do
          expect(az_cloud_factory).to receive(:get_for_az).with('az1', 25).and_return(cloud)
          expect(az_cloud_factory).to receive(:get_for_az).with('az1').and_return(cloud_for_update_metadata)
          expect(cloud).to receive(:attach_disk).with(@instance.vm_cid, @disk.disk_cid)
          expect(cloud_for_update_metadata).to_not receive(:attach_disk)
          expect_any_instance_of(Bosh::Director::MetadataUpdater).to receive(:update_disk_metadata)
            .with(cloud_for_update_metadata, @disk, hash_including(manifest['tags']))
          expect(cloud).not_to receive(:reboot_vm)
          expect(@agent).to receive(:mount_disk).with(@disk.disk_cid)
          @handler.apply_resolution(:reattach_disk)
        end

        context 'rebooting the vm' do
          before do
            allow(base_cloud_factory).to receive(:get).with('cpi1').and_return(cloud)
          end

          it 'attaches disk and reboots the vm' do
            expect(cloud).to receive(:attach_disk).with(@instance.vm_cid, @disk.disk_cid)
            expect(cloud).to receive(:reboot_vm).with(@instance.vm_cid)
            expect(cloud_for_update_metadata).to_not receive(:attach_disk)
            expect(az_cloud_factory).to receive(:get_for_az).with(@instance.availability_zone, 25).and_return(cloud)
            expect(az_cloud_factory).to receive(:get_for_az).with('az1').and_return(cloud_for_update_metadata)
            expect(@agent).to receive(:wait_until_ready)
            expect(@agent).to receive(:mount_disk)
            @handler.apply_resolution(:reattach_disk_and_reboot)
          end

          it 'sets disk metadata with deployment information' do
            expect(cloud).to receive(:attach_disk).with(@instance.vm_cid, @disk.disk_cid)
            expect(cloud).to receive(:reboot_vm).with(@instance.vm_cid)
            expect(cloud_for_update_metadata).to_not receive(:attach_disk)
            expect(az_cloud_factory).to receive(:get_for_az).with(@instance.availability_zone, 25).and_return(cloud)
            expect(az_cloud_factory).to receive(:get_for_az).with('az1').and_return(cloud_for_update_metadata)
            expect(@agent).to receive(:wait_until_ready)
            expect(@agent).to receive(:mount_disk)
            expect_any_instance_of(Bosh::Director::MetadataUpdater).to receive(:update_disk_metadata)
              .with(cloud_for_update_metadata, @disk, hash_including(manifest['tags']))
            @handler.apply_resolution(:reattach_disk_and_reboot)
          end
        end
      end

      context 'cloud API V2' do
        let(:disk_hint) { 'foo' }

        it 'attaches disk' do
          expect(az_cloud_factory).to receive(:get_for_az).with('az1', 25).and_return(cloud)
          expect(az_cloud_factory).to receive(:get_for_az).with('az1').and_return(cloud_for_update_metadata)
          expect(cloud).to receive(:attach_disk).with(@instance.vm_cid, @disk.disk_cid).and_return(disk_hint)
          expect(cloud_for_update_metadata).to_not receive(:attach_disk)
          expect_any_instance_of(Bosh::Director::MetadataUpdater).to receive(:update_disk_metadata)
            .with(cloud_for_update_metadata, @disk, hash_including(manifest['tags']))
          expect(cloud).not_to receive(:reboot_vm)
          expect(@agent).to receive(:add_persistent_disk).with(@disk.disk_cid, disk_hint)
          expect(@agent).to receive(:mount_disk).with(@disk.disk_cid)

          @handler.apply_resolution(:reattach_disk)
        end

        context 'rebooting the vm' do
          before do
            allow(base_cloud_factory).to receive(:get).with('cpi1').and_return(cloud)
          end

          it 'attaches disk and reboots the vm' do
            expect(cloud).to receive(:attach_disk).with(@instance.vm_cid, @disk.disk_cid).and_return(disk_hint)
            expect(cloud).to receive(:reboot_vm).with(@instance.vm_cid)
            expect(cloud_for_update_metadata).to_not receive(:attach_disk)
            expect(az_cloud_factory).to receive(:get_for_az).with(@instance.availability_zone, 25).and_return(cloud)
            expect(az_cloud_factory).to receive(:get_for_az).with('az1').and_return(cloud_for_update_metadata)
            expect(@agent).to receive(:wait_until_ready)
            expect(@agent).to receive(:add_persistent_disk).with(@disk.disk_cid, disk_hint)
            expect(@agent).to receive(:mount_disk)

            @handler.apply_resolution(:reattach_disk_and_reboot)
          end
        end
      end
    end
  end
end
