require 'spec_helper'

module Bosh::Director
  describe InstanceModelHelper do

    describe '#prepare_instance_spec_for_saving!' do
      let(:instance_spec) do
        {
          'properties' => {'name' => 'a'},
          'uninterpolated_properties' => {'name' => '((name_placeholder))'}
        }
      end

      context 'when config server is enabled' do
        before do
          allow(Bosh::Director::Config).to receive(:config_server_enabled).and_return(true)
        end

        it 'only saves uninterpolated properties' do
          prepared_spec = InstanceModelHelper.prepare_instance_spec_for_saving!(instance_spec)
          expect(prepared_spec).to eq({'properties'=>{'name'=>'((name_placeholder))'}})
          expect(prepared_spec.key?('uninterpolated_properties')).to be_falsey
        end
      end

      context 'when config server is disabled' do
        before do
          allow(Bosh::Director::Config).to receive(:config_server_enabled).and_return(false)
        end

        it 'only saves properties' do
          prepared_spec = InstanceModelHelper.prepare_instance_spec_for_saving!(instance_spec)
          expect(prepared_spec).to eq({'properties'=>{'name'=>'a'}})
          expect(prepared_spec.key?('uninterpolated_properties')).to be_falsey
        end
      end
    end

    describe '#adjust_instance_spec_after_retrieval!' do
      let(:retrieved_spec) do
        {'properties' => {'name' => '((name_placeholder))'}}
      end

      context 'when config server is enabled' do
        before do
          allow(Bosh::Director::Config).to receive(:config_server_enabled).and_return(true)
          expect(Bosh::Director::ConfigServer::ConfigParser).to receive(:parse).with({'name' => '((name_placeholder))'}).and_return({'name' => 'Big papa smurf'})
        end

        it 'resolves properties and populates uninterpolated props' do
          result = InstanceModelHelper.adjust_instance_spec_after_retrieval!(retrieved_spec)
          expect(result['properties']).to eq({'name'=>'Big papa smurf'})
          expect(result['uninterpolated_properties']).to eq({'name'=>'((name_placeholder))'})
        end
      end

      context 'when config server is disabled' do
        before do
          allow(Bosh::Director::Config).to receive(:config_server_enabled).and_return(false)
        end

        it 'resolves properties and populates uninterpolated props' do
          result = InstanceModelHelper.adjust_instance_spec_after_retrieval!(retrieved_spec)
          expect(result['properties']).to eq({'name'=>'((name_placeholder))'})
          expect(result['uninterpolated_properties']).to eq({'name'=>'((name_placeholder))'})
        end
      end

    end

  end
end
