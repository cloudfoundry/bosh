require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe PlacementPlanner::IndexAssigner do
    subject(:assigner) { PlacementPlanner::IndexAssigner.new(deployment_model) }
    let(:deployment_model) { FactoryBot.create(:models_deployment) }

    describe 'assign_index' do
      context 'when existing instance model is passed in' do
        context 'when existing instance has same job name' do
          it 'returns index of existing instance' do
            existing_instance_model = FactoryBot.create(:models_instance, job: 'fake-job', index: 5, deployment: deployment_model)
            expect(assigner.assign_index('fake-job', existing_instance_model)).to eq(5)
          end
        end

        context 'when existing instance has different job name' do
          before do
            FactoryBot.create(:models_instance, job: 'fake-job', index: 0, deployment: deployment_model)
            FactoryBot.create(:models_instance, job: 'fake-job', index: 1, deployment: deployment_model)
            FactoryBot.create(:models_instance, job: 'fake-job', index: 2, deployment: deployment_model)
          end

          it 'returns next index' do
            existing_instance_model = FactoryBot.create(:models_instance, job: 'another-job', index: 5)
            expect(assigner.assign_index('fake-job', existing_instance_model)).to eq(3)
          end
        end
      end

      context 'when existing instance model is not passed in' do
        context 'when there are existing instances on that job without gaps' do
          before do
            FactoryBot.create(:models_instance, job: 'fake-job', index: 0, deployment: deployment_model)
            FactoryBot.create(:models_instance, job: 'fake-job', index: 1, deployment: deployment_model)
            FactoryBot.create(:models_instance, job: 'fake-job', index: 2, deployment: deployment_model)
          end

          it 'returns next index' do
            expect(assigner.assign_index('fake-job')).to eq(3)
          end
        end

        context 'when there are existing instances on that job with gaps' do
          before do
            FactoryBot.create(:models_instance, job: 'fake-job', index: 0, deployment: deployment_model)
            FactoryBot.create(:models_instance, job: 'fake-job', index: 2, deployment: deployment_model)
          end

          it 'returns unused index' do
            expect(assigner.assign_index('fake-job')).to eq(1)
          end
        end

        context 'when there are no existing instances on that job' do
          it 'returns 0' do
            expect(assigner.assign_index('fake-job')).to eq(0)
          end
        end
      end
    end
  end
end
