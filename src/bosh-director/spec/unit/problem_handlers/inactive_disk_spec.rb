require File.expand_path('../../../spec_helper', __FILE__)

describe Bosh::Director::ProblemHandlers::InactiveDisk do
  def make_handler(disk_id, data = {})
    Bosh::Director::ProblemHandlers::InactiveDisk.new(disk_id, data)
  end

  let(:cloud) { instance_double(Bosh::Clouds::ExternalCpi) }
  let(:cloud_factory) { instance_double(Bosh::Director::CloudFactory) }

  before(:each) do
    @agent = double('agent')

    @instance = Bosh::Director::Models::Instance.make(
      job: 'mysql_node',
      index: 3,
      uuid: '52C6C66A-6DF3-4D4E-9EB1-FFE63AD755D7',
      availability_zone: 'az1'
    )

    @vm = Bosh::Director::Models::Vm.make(instance_id: @instance.id, stemcell_api_version: 25)
    @instance.active_vm = @vm

    @disk = Bosh::Director::Models::PersistentDisk.
      make(:disk_cid => 'disk-cid', :instance_id => @instance.id,
           :size => 300, :active => false)

    @handler = make_handler(@disk.id)
    allow(@handler).to receive(:cloud).and_return(cloud)
    allow(@handler).to receive(:agent_client).with(@instance.agent_id, @instance.name).and_return(@agent)
    allow(Bosh::Director::CloudFactory).to receive(:create).and_return(cloud_factory)
  end

  it 'registers under inactive_disk type' do
    handler = Bosh::Director::ProblemHandlers::Base.create_by_type(:inactive_disk, @disk.id, {})
    expect(handler).to be_kind_of(Bosh::Director::ProblemHandlers::InactiveDisk)
  end

  it 'has well-formed description' do
    expect(@handler.description).to eq("Disk 'disk-cid' (300M) for instance 'mysql_node/52C6C66A-6DF3-4D4E-9EB1-FFE63AD755D7 (3)' is inactive")
  end

  it 'is not an instance problem' do
    expect(@handler.instance_problem?).to be_falsey
  end

  describe 'invalid states' do
    it 'is invalid if disk is gone' do
      @disk.destroy
      expect {
        make_handler(@disk.id)
      }.to raise_error("Disk '#{@disk.id}' is no longer in the database")
    end

    it 'is invalid if disk is active' do
      @disk.update(:active => true)
      expect {
        make_handler(@disk.id)
      }.to raise_error("Disk 'disk-cid' is no longer inactive")
    end
  end

  describe 'activate_disk resolution' do
    it 'fails if disk is not mounted' do
      expect(@agent).to receive(:list_disk).and_return([])
      expect {
        @handler.apply_resolution(:activate_disk)
      }.to raise_error(Bosh::Director::ProblemHandlerError, 'Disk is not mounted')
    end

    it 'fails if instance has another persistent disk according to DB' do
      Bosh::Director::Models::PersistentDisk.
        make(:instance_id => @instance.id, :active => true)

      expect(@agent).to receive(:list_disk).and_return(['disk-cid'])

      expect {
        @handler.apply_resolution(:activate_disk)
      }.to raise_error(Bosh::Director::ProblemHandlerError, 'Instance already has an active disk')
    end

    it 'marks disk as active in DB' do
      expect(@agent).to receive(:list_disk).and_return(['disk-cid'])
      @handler.apply_resolution(:activate_disk)
      @disk.reload

      expect(@disk.active).to be(true)
    end
  end

  describe 'delete disk solution' do
    let(:event_manager) {Bosh::Director::Api::EventManager.new(true)}
    let(:update_job) {instance_double(Bosh::Director::Jobs::UpdateDeployment, username: 'user', task_id: 42, event_manager: event_manager)}
    before do
      @disk.add_snapshot(Bosh::Director::Models::Snapshot.make)
      allow(Bosh::Director::Config).to receive(:current_job).and_return(update_job)
    end

    it 'fails if disk is mounted' do
      expect(@agent).to receive(:list_disk).and_return(['disk-cid'])
      expect {
        @handler.apply_resolution(:delete_disk)
      }.to raise_error(Bosh::Director::ProblemHandlerError, 'Disk is currently in use')
    end

    it 'detaches disk from VM and deletes it and its snapshots from DB (if instance has VM)' do
      expect(@agent).to receive(:list_disk).and_return(['other-disk'])
      expect(cloud).to receive(:detach_disk).with(@instance.vm_cid, 'disk-cid')
      expect(cloud_factory).to receive(:get).with(@instance.active_vm.cpi, 25).and_return(cloud)
      @handler.apply_resolution(:delete_disk)

      expect(Bosh::Director::Models::PersistentDisk[@disk.id]).to be_nil
      expect(Bosh::Director::Models::Snapshot.all).to be_empty
    end

    it 'ignores cloud errors and proceeds with deletion from DB' do
      expect(@agent).to receive(:list_disk).and_return(['other-disk'])

      expect(cloud).to receive(:detach_disk).with(@instance.vm_cid, 'disk-cid').
        and_raise(RuntimeError.new('Cannot detach disk'))
      expect(cloud_factory).to receive(:get).with(@instance.active_vm.cpi, 25).and_return(cloud)

      @handler.apply_resolution(:delete_disk)

      expect {
        @disk.reload
      }.to raise_error(Sequel::Error, 'Record not found')
    end
  end
end
