require 'spec_helper'

module Bosh::Director
  describe ProblemScanner::ProblemRegister do
    subject(:problem_register) { described_class.new(deployment, logger) }
    let(:deployment) { Models::Deployment.make(name: 'fake-deployment') }
    let(:logger) { double(:logger, info: nil) }

    describe '#problem_found' do
      let(:resource) { double(:resource, id: 123) }
      let(:data) { ['fake-data'] }

      context 'when this deployment problem does not exist' do
        it 'creates deployment problem' do
          problem_register.problem_found('fake-problem-type', resource, data)
          deployment_problem = Bosh::Director::Models::DeploymentProblem.all.first
          expect(deployment_problem.deployment_id).to eq(deployment.id)
          expect(deployment_problem.type).to eq('fake-problem-type')
          expect(deployment_problem.resource_id).to eq(123)
          expect(deployment_problem.state).to eq('open')
          expect(deployment_problem.data).to eq(data)
          expect(deployment_problem.counter).to eq(1)
        end
      end

      context 'when there is the same deployment problem' do
        before do
          Bosh::Director::Models::DeploymentProblem.make(
            deployment_id: deployment.id,
            type: 'fake-problem-type',
            resource_id: 123,
            state: 'open',
            counter: 1
          )
        end

        it 'updates deployment problem' do
          problem_register.problem_found('fake-problem-type', resource, data)
          deployment_problem = Bosh::Director::Models::DeploymentProblem.all.first

          expect(deployment_problem.deployment_id).to eq(deployment.id)
          expect(deployment_problem.type).to eq('fake-problem-type')
          expect(deployment_problem.resource_id).to eq(123)
          expect(deployment_problem.state).to eq('open')
          expect(deployment_problem.data).to eq(data)
          expect(deployment_problem.counter).to eq(2)
          expect(deployment_problem.last_seen_at).to_not be_nil
        end
      end

      context 'when there are more than 1 similar deployment problems' do
        before do
          2.times do
            Bosh::Director::Models::DeploymentProblem.make(
              deployment_id: deployment.id,
              type: 'fake-problem-type',
              resource_id: 123,
              state: 'open',
              counter: 1
            )
          end
        end

        it 'raises an error' do
          expect {
            problem_register.problem_found('fake-problem-type', resource, data)
          }.to raise_error(Bosh::Director::CloudcheckTooManySimilarProblems)
        end
      end
    end

    describe '#get_vm_instance_and_disk' do
      let(:instance) { double(:instance, persistent_disk_cid: 'fake-disk-cid') }
      let(:vm) { double(:vm, instance: instance) }

      it 'returns vm instance and disk' do
        vm_instance, mounted_disk_cid = problem_register.get_vm_instance_and_disk(vm)
        expect(vm_instance).to eq(instance)
        expect(mounted_disk_cid).to eq('fake-disk-cid')
      end
    end
  end
end
