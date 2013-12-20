require 'spec_helper'

describe Bosh::Director::JobUpdater do
  subject(:job_updater) { described_class.new(@deployment_plan, @job_spec) }

  before do
    @deployment_plan = double("deployment_plan")
    @update_spec = double("update_spec", max_in_flight: 5, canaries: 1)
    @job_spec = double("job_spec", update: @update_spec, name: 'job_name')
  end

  before { Bosh::Director::Config.stub(:cloud).and_return(nil) }

  it "should do nothing when the job is up to date" do
    instance_1 = double("instance-1")
    instance_1.stub(:index).and_return(1)
    instance_2 = double("instance-1")
    instance_2.stub(:index).and_return(2)

    instances = [instance_1, instance_2]

    @job_spec.should_receive(:instances).and_return(instances)
    @job_spec.should_receive(:unneeded_instances).and_return([])
    instance_1.should_receive(:changed?).and_return(false)
    instance_2.should_receive(:changed?).and_return(false)

    job_updater.update
  end

  it "should update the job with canaries" do
    instance_1 = double("instance-1")
    instance_1.stub(:index).and_return(1)
    instance_2 = double("instance-1")
    instance_2.stub(:index).and_return(2)
    instances = [instance_1, instance_2]

    instance_updater_1 = double("instance_updater_1")
    instance_updater_2 = double("instance_updater_2")

    @job_spec.should_receive(:instances).and_return(instances)
    @job_spec.should_receive(:unneeded_instances).and_return([])
    @job_spec.stub(:should_halt?).and_return(false)

    instance_1.should_receive(:changed?).and_return(true)
    instance_2.should_receive(:changed?).and_return(true)

    instance_updater_1.should_receive(:update).with(:canary => true)
    instance_updater_2.should_receive(:update).with(no_args)

    Bosh::Director::InstanceUpdater.stub(:new).and_return do |instance, _|
      case instance
        when instance_1
          instance_updater_1
        when instance_2
          instance_updater_2
        else
          raise "unknown instance"
      end
    end

    job_updater.update

    check_event_log do |events|
      events.size.should == 4
      events.map { |e| e["stage"] }.uniq.should == ["Updating job"]
      events.map { |e| e["tags"] }.uniq.should == [ ["job_name"] ]
      events.map { |e| e["total"] }.uniq.should == [2]
      events.map { |e| e["task"] }.should == ["job_name/1 (canary)", "job_name/1 (canary)", "job_name/2", "job_name/2"]
    end
  end

  it 'logs instance updates to event log ensuring that stage tags associations are preserved' do
    event_log = instance_double('Bosh::Director::EventLog::Log')
    Bosh::Director::Config.stub(:event_log).and_return(event_log)

    event_log_stage = instance_double('Bosh::Director::EventLog::Stage')
    event_log.stub(:begin_stage).with('Updating job', 2, ['job_name']).and_return(event_log_stage)

    # Using Stage for tracking task makes event log thread-safe
    event_log_stage.should_receive(:advance_and_track).with('job_name/1 (canary)')
    event_log_stage.should_receive(:advance_and_track).with('job_name/2')

    instance_1 = double('instance-1', index: 1)
    instance_2 = double('instance-1', index: 2)
    @job_spec.should_receive(:instances).and_return([instance_1, instance_2])
    @job_spec.should_receive(:unneeded_instances).and_return([])
    @job_spec.stub(:should_halt?).and_return(false)

    instance_1.should_receive(:changed?).and_return(true)
    instance_2.should_receive(:changed?).and_return(true)

    instance_updater = instance_double('Bosh::Director::InstanceUpdater', update: nil)
    Bosh::Director::InstanceUpdater.stub(:new).and_return(instance_updater)

    job_updater.update
  end

  it "should rollback the job if the canaries failed" do
    instance_1 = double("instance-1")
    instance_1.stub(:index).and_return(1)
    instance_2 = double("instance-1")
    instance_2.stub(:index).and_return(2)
    instances = [instance_1, instance_2]

    instance_updater_1 = double("instance_updater_1")
    instance_updater_2 = double("instance_updater_2")

    @job_spec.stub(:should_halt?).and_return(false, true)
    @job_spec.should_receive(:instances).and_return(instances)
    @job_spec.should_receive(:record_update_error).with(anything, :canary => true)
    @job_spec.should_receive(:unneeded_instances).and_return([])
    @job_spec.stub(:halt_exception).and_return("bad update")

    instance_1.should_receive(:changed?).and_return(true)
    instance_2.should_receive(:changed?).and_return(true)

    instance_updater_1.should_receive(:update).with(:canary => true).and_throw("bad update")
    instance_updater_2.should_not_receive(:update).with(no_args)

    Bosh::Director::InstanceUpdater.stub(:new).and_return do |instance, ticker|
      case instance
        when instance_1
          instance_updater_1
        when instance_2
          instance_updater_2
        else
          raise "unknown instance"
      end
    end

    lambda { job_updater.update }.should raise_exception(RuntimeError, "bad update")
  end

  it "should rollback the job if it exceeded max number of errors" do
    instance_1 = double("instance-1")
    instance_1.stub(:index).and_return(1)
    instance_2 = double("instance-1")
    instance_2.stub(:index).and_return(2)
    instances = [instance_1, instance_2]

    instance_updater_1 = double("instance_updater_1")
    instance_updater_2 = double("instance_updater_2")

    @job_spec.stub(:should_halt?).and_return(false, false, false, true)
    @job_spec.should_receive(:unneeded_instances).and_return([])
    @job_spec.should_receive(:instances).and_return(instances)
    @job_spec.should_receive(:record_update_error).with(anything)
    @job_spec.stub(:halt_exception).and_return("zb")

    instance_1.should_receive(:changed?).and_return(true)
    instance_2.should_receive(:changed?).and_return(true)

    instance_updater_1.should_receive(:update).with(:canary => true)
    instance_updater_2.should_receive(:update).with(no_args).and_throw("bad update")

    Bosh::Director::InstanceUpdater.stub(:new).and_return do |instance, ticker|
      case instance
        when instance_1
          instance_updater_1
        when instance_2
          instance_updater_2
        else
          raise "unknown instance"
      end
    end

    lambda { job_updater.update }.should raise_exception(RuntimeError, "zb")
  end

  it "deletes unneeded instances" do
    instance = double("instance")
    @job_spec.stub(:instances).and_return([])
    @job_spec.stub(:unneeded_instances).and_return([instance])

    instance_deleter = instance_double('Bosh::Director::InstanceDeleter')
    Bosh::Director::InstanceDeleter.stub(:new).with(@deployment_plan).and_return(instance_deleter)

    event_log = instance_double('Bosh::Director::EventLog::Log')
    Bosh::Director::Config.stub(:event_log).and_return(event_log)

    event_log_stage = instance_double('Bosh::Director::EventLog::Stage')
    event_log.stub(:begin_stage).with('Deleting unneeded instances', 1, ['job_name']).and_return(event_log_stage)

    instance_deleter
      .should_receive(:delete_instances)
      .with([instance], event_log_stage, max_threads: 5)

    job_updater.update
  end
end
