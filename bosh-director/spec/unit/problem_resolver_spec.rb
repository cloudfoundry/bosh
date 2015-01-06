require 'spec_helper'

module Bosh::Director
  describe ProblemResolver do
    before(:each) do
      @deployment = Models::Deployment.make(name: 'mycloud')
      @other_deployment = Models::Deployment.make(name: 'othercloud')

      @cloud = instance_double('Bosh::Cloud')
      allow(Config).to receive(:cloud).and_return(@cloud)
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
      expect(agent).to receive(:list_disk).and_return([])

      expect(@cloud).to receive(:detach_disk).exactly(1).times
      expect(@cloud).to receive(:delete_disk).exactly(1).times

      allow(AgentClient).to receive(:with_defaults).and_return(agent)

      2.times do
        disk = Models::PersistentDisk.make(:active => false)
        disks << disk
        problems << inactive_disk(disk.id)
      end

      job = make_job(@deployment)

      expect(job.apply_resolutions({ problems[0].id.to_s => 'delete_disk', problems[1].id.to_s => 'ignore' })).to eq(2)

      expect(Models::PersistentDisk.find(id: disks[0].id)).to be_nil
      expect(Models::PersistentDisk.find(id: disks[1].id)).not_to be_nil

      expect(Models::DeploymentProblem.filter(state: 'open').count).to eq(0)
    end

    it 'notices and logs extra resolutions' do
      disks = (1..3).map { |_| Models::PersistentDisk.make(:active => false) }

      problems = [
        inactive_disk(disks[0].id),
        inactive_disk(disks[1].id),
        inactive_disk(disks[2].id, @other_deployment.id)
      ]

      job1 = make_job(@deployment)
      expect(job1.apply_resolutions({ problems[0].id.to_s => 'ignore', problems[1].id.to_s => 'ignore' })).to eq(2)

      job2 = make_job(@deployment)

      messages = []
      expect(job2).to receive(:track_and_log).exactly(3).times { |message| messages << message }
      job2.apply_resolutions({
                               problems[0].id.to_s => 'ignore',
                               problems[1].id.to_s => 'ignore',
                               problems[2].id.to_s => 'ignore',
                               'foobar' => 'ignore',
                               '318' => 'do_stuff'
                             })

      expect(messages).to match_array([
        "Ignoring problem #{problems[0].id} (state is 'resolved')",
        "Ignoring problem #{problems[1].id} (state is 'resolved')",
        "Ignoring problem #{problems[2].id} (not a part of this deployment)",
      ])
    end
  end
end
