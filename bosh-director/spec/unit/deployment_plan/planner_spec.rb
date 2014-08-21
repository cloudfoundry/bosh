require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    describe Planner do
      subject { described_class.new('fake-dep-name') }

      let(:logger) { Logger.new('/dev/null') }
      let(:event_log) { instance_double('Bosh::Director::EventLog::Log') }

      describe 'parse' do
        it 'parses disk_pools' do
          manifest = minimal_manifest
          manifest['disk_pools'] = [
            {
              'name' => 'disk_pool1',
              'disk_size' => 3000,
            },
            {
              'name' => 'disk_pool2',
              'disk_size' => 1000,
            },
          ]
          planner = Planner.parse(manifest, {}, event_log, logger)
          expect(planner.disk_pools.length).to eq(2)
          expect(planner.disk_pool('disk_pool1').disk_size).to eq(3000)
          expect(planner.disk_pool('disk_pool2').disk_size).to eq(1000)
        end
      end

      def minimal_manifest
        {
          'name' => 'minimal',
          # 'director_uuid'  => 'deadbeef',

          'releases' => [{
            'name'    => 'appcloud',
            'version' => '0.1' # It's our dummy valid release from spec/assets/valid_release.tgz
          }],

          'networks' => [{
            'name' => 'a',
            'subnets' => [],
          }],

          'compilation' => {
            'workers' => 1,
            'network' => 'a',
            'cloud_properties' => {},
          },

          'resource_pools' => [],

          'update' => {
            'canaries'          => 2,
            'canary_watch_time' => 4000,
            'max_in_flight'     => 1,
            'update_watch_time' => 20
          }
        }
      end

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
            vm_model1 = Models::Vm.make(deployment: deployment)
            vm_model2 = Models::Vm.make(deployment: deployment)

            plan.bind_model
            plan.vms.should =~ [vm_model1, vm_model2]
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
