require 'spec_helper'
require 'bosh/director/api/instance_lookup'

module Bosh::Director
  module Api
    describe InstanceLookup do
      subject(:instance_lookup) { InstanceLookup.new }
      let!(:instance) { Models::Instance.make(deployment: deployment, job: job_name, index: job_index) }
      let!(:another_instance) { Models::Instance.make(deployment: deployment, job: job_name, index: another_job_index) }
      let(:deployment) { Models::Deployment.make(name: 'foobar') }
      let(:job_name) { 'my_job' }
      let(:job_index) { '6' }
      let(:another_job_index) { '0' }

      describe '.by_id' do
        it 'finds instance for id' do
          expect(instance_lookup.by_id(instance.id)).to eq instance
        end

        context 'no instance exists for id' do
          it 'raises' do
            expect {
              instance_lookup.by_id(999999)
            }.to raise_error(InstanceNotFound, "Instance 999999 doesn't exist")
          end
        end
      end

      describe '.by_attributes' do
        it 'finds instance based on attribute vector' do
          expect(instance_lookup.by_attributes(deployment, job_name, job_index)).to eq(instance)
        end

        context 'no instance exists for attribute vector' do
          it 'raises' do
            expect {
              instance_lookup.by_attributes(deployment, job_name, '7')
            }.to raise_error(InstanceNotFound, "'#{deployment.name}/#{job_name}/7' doesn't exist")
          end
        end

        context 'when attributes are are empty strings' do
          let(:cleansed_filter_attributes) { { deployment: anything, job: '', index: nil } }

          it 'converts the empty string to nil so that postgres will not raise on trying to convert an empty string to integer' do
            expect(Models::Instance).to receive(:find).with(cleansed_filter_attributes).and_return(instance)
            expect { instance_lookup.by_attributes(deployment, '', '') }.to_not raise_error
          end
        end
      end

      describe '.by_filter' do
        it 'finds only instances that match sql filter' do
          expect(instance_lookup.by_filter(id: instance.id).all).to eq([instance])
        end

        context 'no instances exist for sql filter' do
          it 'raises' do
            expect {
              instance_lookup.by_filter(id: 987654321)
            }.to raise_error(InstanceNotFound, "No instances matched {:id=>987654321}")
          end
        end
      end

      describe '.find_all' do
        it 'pulls all instances' do
          expect(instance_lookup.find_all).to eq [instance, another_instance]
        end
      end

      describe '#by_deployment' do
        context 'when multiple deployments have instances' do
          before do
            other_deployment = Models::Deployment.make(name: 'other_deployment')
            Models::Instance.make(deployment: other_deployment)
            @deployment = Models::Deployment.make(name: 'given_deployment')
            @instance = Models::Instance.make(deployment: @deployment)
          end

          it 'finds only the instance from given deployment' do
            expect(subject.by_deployment(@deployment)).to eq [@instance]
          end
        end

        context 'when deployment has no instances' do
          it 'finds no instances' do
            deployment = Models::Deployment.make(name: 'deployment_without_instance')

            expect(subject.by_deployment(deployment)).to eq []
          end
        end
      end

      describe '#by_vm_cid' do
        context 'when vm with cid is active vm for instance' do
          before do
            vm = Models::Vm.make(cid: 'vm-cid', instance: instance, active: true)
            vm.save
          end

          it 'finds the instance with the vm' do
            expect(subject.by_vm_cid('vm-cid')).to eq([instance])
          end
        end

        context 'when the vm is not found as active on instance' do
          before do
            vm = Models::Vm.make(cid: 'vm-cid', instance: instance, active: false)
            vm.save
          end

          it 'finds no instances' do
            expect {
              instance_lookup.by_vm_cid('vm-cid')
            }.to raise_error(InstanceNotFound, "No instances matched vm cid 'vm-cid'")
          end
        end
      end
    end
  end
end
