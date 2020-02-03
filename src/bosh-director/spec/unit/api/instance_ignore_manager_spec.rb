require 'spec_helper'

module Bosh::Director
  module Api
    describe InstanceIgnoreManager do
      let(:instance) { instance_double('Bosh::Director::Models::Instance') }
      let(:instances) { [instance] }
      let(:instance_lookup) do
        instance_double('Bosh::Director::Api::InstanceLookup',
                        by_attributes: instance,
                        by_uuid:       instance,
                        find_all:      instances
        )
      end
      subject(:ignore_instance_manager) { InstanceIgnoreManager.new }

      before do
        allow(InstanceLookup).to receive_messages(new: instance_lookup)
      end

      describe 'set_ignore_for_instance' do
        context 'get instance by uuid' do
          let(:deployment_name) { 'DEPLOYMENT' }
          let(:instance_group_name) { 'INSTANCE_GROUP' }
          let(:index_or_id) { '4153fb47-1565-4873-a541-3c50e4bfec04' }

          it 'should change ignore state to true' do
            expect(instance_lookup).to receive(:by_uuid)
            expect(instance_lookup).to_not receive(:by_attributes)
            expect(instance).to receive(:ignore=).with(true).ordered
            expect(instance).to receive(:save).ordered
            ignore_instance_manager.set_ignore_state_for_instance(deployment_name, instance_group_name, index_or_id, true)
          end

          it 'should change ignore state to false' do
            expect(instance_lookup).to receive(:by_uuid)
            expect(instance_lookup).to_not receive(:by_attributes)
            expect(instance).to receive(:ignore=).with(false).ordered
            expect(instance).to receive(:save).ordered
            ignore_instance_manager.set_ignore_state_for_instance(deployment_name, instance_group_name, index_or_id, false)
          end
        end

        context 'get instance by index' do
          let(:deployment_name) { 'DEPLOYMENT' }
          let(:instance_group_name) { 'INSTANCE_GROUP' }
          let(:index_or_id) { '0' }

          it 'should change ignore state to true' do
            expect(instance_lookup).to_not receive(:by_uuid)
            expect(instance_lookup).to receive(:by_attributes)
            expect(instance).to receive(:ignore=).with(true).ordered
            expect(instance).to receive(:save).ordered
            ignore_instance_manager.set_ignore_state_for_instance(deployment_name, instance_group_name, index_or_id, true)
          end
        end
      end
    end
  end
end
