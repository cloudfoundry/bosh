require 'spec_helper'

module Bosh::Director
  module Api
    describe ResurrectorManager do
      let(:instance) { instance_double('Bosh::Director::Models::Instance') }
      let(:instances) { [instance] }
      let(:instance_lookup) do
        instance_double('Bosh::Director::Api::InstanceLookup',
                        by_attributes: instance,
                        by_uuid:       instance,
                        find_all:      instances
        )
      end
      subject(:resurrection_manager) { ResurrectorManager.new }

      before do
        allow(InstanceLookup).to receive_messages(new: instance_lookup)
      end

      describe 'set_pause_for_all' do
        context 'setting pause to true' do
          it 'configures all instances to pause resurrection functionality' do
            resurrection_manager.set_pause_for_all(true)
            expect(Models::DirectorAttribute.first(name: 'resurrection_paused').value).to eq('true')
          end
        end

        context 'setting pause to false' do
          it 'configures all instances to (re)start resurrection functionality' do
            resurrection_manager.set_pause_for_all(false)
            expect(Models::DirectorAttribute.first(name: 'resurrection_paused').value).to eq('false')
          end
        end

        context 'setting pause several times' do
          it 'creates one record in DB' do
            expect(Models::DirectorAttribute.where(name: 'resurrection_paused').count).to eq(0)
            3.times do
              resurrection_manager.set_pause_for_all(false)
            end
            expect(Models::DirectorAttribute.where(name: 'resurrection_paused').count).to eq(1)
            expect(Models::DirectorAttribute.first(name: 'resurrection_paused').value).to eq('false')
          end
        end
      end

      describe 'pause_for_all?' do
        context 'when resurrection_paused director attribute is not set' do
          it 'returns false' do
            expect(Models::DirectorAttribute.first(name: 'resurrection_paused')).to be_nil
            expect(resurrection_manager.pause_for_all?).to eq(false)
          end
        end
        context 'when resurrection_paused director attribute is set' do
          it 'returns true' do
            FactoryBot.create(:models_director_attribute, name: 'resurrection_paused', value: 'true')
            expect(resurrection_manager.pause_for_all?).to eq(true)
          end
          it 'returns false' do
            FactoryBot.create(:models_director_attribute, name: 'resurrection_paused', value: 'false')
            expect(resurrection_manager.pause_for_all?).to eq(false)
          end
        end
      end
    end
  end
end
