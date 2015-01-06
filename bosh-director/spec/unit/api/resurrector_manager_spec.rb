require 'spec_helper'

module Bosh::Director
  module Api
    describe ResurrectorManager do
      let(:instance) { instance_double('Bosh::Director::Models::Instance') }
      let(:instances) { [instance] }
      let(:instance_lookup) do
        instance_double('Bosh::Director::Api::InstanceLookup',
                        by_attributes: instance,
                        find_all:      instances
        )
      end
      subject(:resurrection_manager) { ResurrectorManager.new }

      before do
        allow(InstanceLookup).to receive_messages(new: instance_lookup)
      end

      describe 'set_pause_for_instance' do
        let(:deployment_name) { 'DEPLOYMENT' }
        let(:job_name) { 'JOB' }
        let(:job_index) { '3' }

        context 'setting pause to true' do
          it 'configures the instance to pause resurrection functionality' do
            expect(instance).to receive(:resurrection_paused=).with(true).ordered
            expect(instance).to receive(:save).ordered
            resurrection_manager.set_pause_for_instance(deployment_name, job_name, job_index, true)
          end
        end

        context 'setting pause to false' do
          it 'configures the instance to (re)start resurrection functionality' do
            expect(instance).to receive(:resurrection_paused=).with(false).ordered
            expect(instance).to receive(:save).ordered
            resurrection_manager.set_pause_for_instance(deployment_name, job_name, job_index, false)
          end
        end
      end

      describe 'set_pause_for_all' do
        context 'setting pause to true' do
          it 'configures all instances to pause resurrection functionality' do
            expect(Models::Instance).to receive(:update).with(resurrection_paused: true)
            resurrection_manager.set_pause_for_all(true)
          end
        end

        context 'setting pause to false' do
          it 'configures all instances to (re)start resurrection functionality' do
            expect(Models::Instance).to receive(:update).with(resurrection_paused: false)
            resurrection_manager.set_pause_for_all(false)
          end
        end
      end
    end
  end
end