require 'spec_helper'

module Bosh::Director
  describe InstanceUpdater::InstanceState do
    subject(:instance_state) { described_class }

    describe 'with_instance_update' do
      let(:instance_model) { FactoryBot.create(:models_instance, uuid: 'fake-uuid') }

      context 'when block execution fails' do
        let(:instance_model) { FactoryBot.create(:models_instance, uuid: 'fake-uuid', update_completed: true) }

        it 'marks instances as dirty' do
          expect {
            instance_state.with_instance_update(instance_model) do
              raise 'Failed to update instance'
            end
          }.to raise_error 'Failed to update instance'

          expect(Models::Instance.find(uuid: 'fake-uuid').update_completed).to be(false)
        end
      end

      context 'when block execution succeeds' do
        let(:instance_model) { FactoryBot.create(:models_instance, uuid: 'fake-uuid', update_completed: true) }

        it 'marks instances as updated' do
          expect {
            instance_state.with_instance_update(instance_model) do
              # nothing
            end
          }.to_not raise_error

          expect(Models::Instance.find(uuid: 'fake-uuid').update_completed).to be(true)
        end
      end
    end
  end
end
