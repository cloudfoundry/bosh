require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    describe Planner do
      subject { described_class.new('fake-dep-name') }

      describe '#initialize' do
        it 'raises an error if name is not given' do
          expect {
            described_class.new(nil, {})
          }.to raise_error(ArgumentError, 'name must not be nil')
        end

        describe 'options' do
          it 'should parse recreate' do
            plan = Planner.new('name', {})
            expect(plan.recreate).to eq(false)

            plan = Planner.new('name', 'recreate' => true)
            expect(plan.recreate).to eq(true)
          end
        end
      end

      describe '#bind_model' do
        describe 'binding deployment model' do
          it 'creates new deployment in DB using name from the manifest' do
            plan = make_plan('mycloud')

            find_deployment('mycloud').should be_nil
            plan.bind_model

            plan.model.should == find_deployment('mycloud')
            Models::Deployment.count.should == 1
          end

          it 'uses an existing deployment model if found in DB' do
            plan = make_plan('mycloud')

            deployment = make_deployment('mycloud')
            plan.bind_model
            plan.model.should == deployment
            Models::Deployment.count.should == 1
          end

          it 'enforces canonical name uniqueness' do
            make_deployment('my-cloud')
            plan = make_plan('my_cloud')

            expect {
              plan.bind_model
            }.to raise_error(DeploymentCanonicalNameTaken)

            plan.model.should be_nil
            Models::Deployment.count.should == 1
          end
        end

        describe 'getting VM models list' do
          it 'raises an error when deployment model is unbound' do
            plan = make_plan('my_cloud')

            expect {
              plan.vms
            }.to raise_error(DirectorError)

            make_deployment('mycloud')
            plan.bind_model
            lambda { plan.vms }.should_not raise_error
          end

          it 'returns a list of VMs in deployment' do
            plan = make_plan('my_cloud')

            deployment = make_deployment('my_cloud')
            vm1 = Models::Vm.make(deployment: deployment)
            vm2 = Models::Vm.make(deployment: deployment)

            plan.bind_model
            plan.vms.should =~ [vm1, vm2]
          end
        end

        def make_plan(name)
          Planner.new(name, {})
        end

        def find_deployment(name)
          Models::Deployment.find(name: name)
        end

        def make_deployment(name)
          Models::Deployment.make(name: name)
        end
      end

      describe '#jobs_starting_on_deploy' do
        before { subject.add_job(job1) }
        let(:job1) do
          instance_double('Bosh::Director::DeploymentPlan::Job', {
            name: 'fake-job1-name',
            canonical_name: 'fake-job1-cname',
          })
        end

        before { subject.add_job(job2) }
        let(:job2) do
          instance_double('Bosh::Director::DeploymentPlan::Job', {
            name: 'fake-job2-name',
            canonical_name: 'fake-job2-cname',
          })
        end

        context 'when there is at least one job that runs when deploy starts' do
          before { allow(job1).to receive(:starts_on_deploy?).with(no_args).and_return(false) }
          before { allow(job2).to receive(:starts_on_deploy?).with(no_args).and_return(true) }

          it 'only returns jobs that start on deploy' do
            expect(subject.jobs_starting_on_deploy).to eq([job2])
          end
        end

        context 'when there are no jobs that run when deploy starts' do
          before { allow(job1).to receive(:starts_on_deploy?).with(no_args).and_return(false) }
          before { allow(job2).to receive(:starts_on_deploy?).with(no_args).and_return(false) }

          it 'only returns jobs that start on deploy' do
            expect(subject.jobs_starting_on_deploy).to eq([])
          end
        end
      end
    end
  end
end
