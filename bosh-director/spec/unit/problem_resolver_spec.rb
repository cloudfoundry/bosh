require 'spec_helper'

module Bosh::Director
  describe ProblemResolver do
    before(:each) do
      @deployment = Models::Deployment.make(name: 'mycloud')
      @other_deployment = Models::Deployment.make(name: 'othercloud')

      @cloud = instance_double('Bosh::Cloud')
      Config.stub(:cloud).and_return(@cloud)
    end

    def make_job(deployment)
      ProblemResolver.new(deployment)
    end

    def inactive_disk(id, deployment_id = nil)
      Models::DeploymentProblem.make(deployment_id: deployment_id || @deployment.id,
                                     resource_id: id,
                                     type: 'inactive_disk',
                                     state: 'open')
    end

    it 'applies resolutions' do
      disks = []
      problems = []

      agent = double('agent')
      agent.should_receive(:list_disk).and_return([])

      @cloud.should_receive(:detach_disk).exactly(1).times
      @cloud.should_receive(:delete_disk).exactly(1).times

      AgentClient.stub(:with_defaults).and_return(agent)

      2.times do
        disk = Models::PersistentDisk.make(:active => false)
        disks << disk
        problems << inactive_disk(disk.id)
      end

      job = make_job(@deployment)

      job.apply_resolutions({ problems[0].id.to_s => 'delete_disk', problems[1].id.to_s => 'ignore' }).should == 2

      Models::PersistentDisk.find(id: disks[0].id).should be_nil
      Models::PersistentDisk.find(id: disks[1].id).should_not be_nil

      Models::DeploymentProblem.filter(state: 'open').count.should == 0
    end

    it 'whines on missing resolutions' do
      problem = inactive_disk(22)

      job = make_job(@deployment)

      lambda {
        job.apply_resolutions({ 32 => 'delete_disk' })
      }.should raise_error(CloudcheckResolutionNotProvided,
                           "Resolution for problem #{problem.id} (inactive_disk) is not provided")
    end

    it 'notices and logs extra resolutions' do
      disks = (1..3).map { |_| Models::PersistentDisk.make(:active => false) }

      problems = [
        inactive_disk(disks[0].id),
        inactive_disk(disks[1].id),
        inactive_disk(disks[2].id, @other_deployment.id)
      ]

      job1 = make_job(@deployment)
      job1.apply_resolutions({ problems[0].id.to_s => 'ignore', problems[1].id.to_s => 'ignore' }).should == 2

      job2 = make_job(@deployment)

      messages = []
      job2.should_receive(:track_and_log).exactly(5).times.and_return { |message| messages << message }
      job2.apply_resolutions({
                               problems[0].id.to_s => 'ignore',
                               problems[1].id.to_s => 'ignore',
                               problems[2].id.to_s => 'ignore',
                               'foobar' => 'ignore',
                               '318' => 'do_stuff'
                             })

      messages.should =~ [
        "Ignoring problem #{problems[0].id} (state is 'resolved')",
        "Ignoring problem #{problems[1].id} (state is 'resolved')",
        'Ignoring problem 318 (not found)',
        "Ignoring problem #{problems[2].id} (not a part of this deployment)",
        'Ignoring problem foobar (malformed id)'
      ]
    end
  end
end
