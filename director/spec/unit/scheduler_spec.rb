require 'spec_helper'
require 'director/scheduler'

describe Bosh::Director::Scheduler do


  let(:cloud) {stub(:Cloud)}
  let(:uuid) {'deadbeef'}
  let(:director_name) {'Test Director'}

  before do
    BD::Config.stub(:cloud).and_return(cloud)
    BD::Config.stub(:uuid).and_return(uuid)
    BD::Config.stub(:name).and_return(director_name)
  end

  describe 'scheduling jobs' do
    let(:scheduled_jobs) { [{'schedule' => '0 1 * * *', 'command' => 'snapshot_deployments'}] }
    subject { described_class.new(scheduled_jobs) }

    it 'schedules jobs at the appropriate time' do
      fake_scheduler = double('Scheduler')
      subject.stub(:scheduler).and_return(fake_scheduler)
      fake_scheduler.should_receive(:cron).with('0 1 * * *').and_yield(double('Job', next_time: "tomorrow"))
      subject.should_receive(:snapshot_deployments)
      subject.add_jobs
    end

  end

  describe 'job commands' do
    describe 'snapshot_deployments' do
      let(:deployments) { [BDM::Deployment.make, BDM::Deployment.make]}

      it 'creates a snapshot deployment task for each deployment' do
        fake_snapshot_manager = double('Snapshot Manager')
        Bosh::Director::Api::SnapshotManager.stub(:new).and_return(fake_snapshot_manager)
        fake_snapshot_manager.should_receive(:create_deployment_snapshot_task).with('scheduler', deployments[0])
        fake_snapshot_manager.should_receive(:create_deployment_snapshot_task).with('scheduler', deployments[1])
        subject.snapshot_deployments
      end
    end

    describe 'snapshot_self' do
     it 'should snapshot all of my disks' do
       vm_id = "id-foo"
       disks = ["vol-id1", "vol-id2"]
       metadata = {
           deployment: 'self',
           job: 'director',
           index: 0,
           director_name: director_name,
           director_uuid: uuid,
           agent_id: 'self',
           instance_id: vm_id
       }
       cloud.should_receive(:current_vm_id).and_return(vm_id)
       cloud.should_receive(:get_disks).with(vm_id).and_return(disks)
       cloud.should_receive(:snapshot_disk).with(disks[0], metadata)
       cloud.should_receive(:snapshot_disk).with(disks[1], metadata)
       subject.snapshot_self
     end
    end
  end

end