require 'spec_helper'

module Bosh::Director
  describe DiskDeleter do
    subject(:deleter) { described_class.new(per_spec_logger, disk_manager, {}) }
    let(:disk_manager) { DiskManager.new(per_spec_logger) }
    let(:options) { {} }
    let(:event_log) { Bosh::Director::EventLog::Log.new(task_writer) }
    let(:event_log_stage) { instance_double('Bosh::Director::EventLog::Stage') }
    let!(:deployment_model) { FactoryBot.create(:models_deployment, name: 'fake-deployment') }
    let(:delete_job) { Jobs::DeleteDeployment.new('test_deployment', {}) }
    let(:task) { FactoryBot.create(:models_task, id: 42, username: 'user') }

    before do
      allow(event_log_stage).to receive(:advance_and_track).and_yield
      allow(delete_job).to receive(:task_id).and_return(task.id)
      allow(Config).to receive(:current_job).and_return(delete_job)
    end

    describe '#delete_dynamic_disks' do
      let(:five_disks) {
        5.times.map do | index |
          FactoryBot.create(:models_dynamic_disk, deployment: deployment_model)
        end
      }

      it 'should delete disks with the config max threads option' do
        allow(Config).to receive(:max_threads).and_return(5)
        pool = double('pool')
        expect(ThreadPool).to receive(:new).with(max_threads: 5).and_return(pool)
        expect(pool).to receive(:wrap).and_yield(pool)
        expect(pool).to receive(:process).exactly(5).times.and_yield


        5.times do |  index|
          expect(disk_manager).to receive(:delete_dynamic_disk).with(five_disks[index])
        end

        deleter.delete_dynamic_disks(deployment_model, event_log_stage)
      end
    end
  end
end
