require 'spec_helper'

module Bosh::Director
  describe InstanceModelHelper do

    describe '#prepare_instance_spec_for_saving!' do
      let(:instance_spec) do
        {
          'env' => {'a' => 'a_value'},
          'uninterpolated_env' => {'a' => '((a_placeholder))'},
          'properties' => {'name' => 'a'},
          'uninterpolated_properties' => {'name' => '((name_placeholder))'},
          'links' => {
            'link_name' => {
              'instances' => [{
                                'name' => 'external_db',
                                'address' => '192.168.15.4'
                              }],
              'properties' => {
                'a' => 'a_value',
                'b' => 'b_value',
                'c' => 'c_value'
              },
              'uninterpolated_properties' => {
                'a' => '((a_placeholder))',
                'b' => '((b_placeholder))',
                'c' => 'c_value'
              }
            }
          }
        }
      end

      context 'when config server is enabled' do
        before do
          allow(Bosh::Director::Config).to receive(:config_server_enabled).and_return(true)
        end

        it 'only keeps uninterpolated spec properties' do
          prepared_spec = InstanceModelHelper.prepare_instance_spec_for_saving!(instance_spec)
          expect(prepared_spec['properties']).to eq({'name'=>'((name_placeholder))'})
          expect(prepared_spec.key?('uninterpolated_properties')).to be_falsey
        end

        it 'only keeps uninterpolated links properties' do
          prepared_spec = InstanceModelHelper.prepare_instance_spec_for_saving!(instance_spec)
          expect(prepared_spec['links']['link_name']['properties']).to eq({'a' => '((a_placeholder))',
                                                                           'b' => '((b_placeholder))',
                                                                           'c' => 'c_value'})
          expect(prepared_spec['links']['link_name'].key?('uninterpolated_properties')).to be_falsey
        end

        it 'only keeps uninterpolated env properties' do
          prepared_spec = InstanceModelHelper.prepare_instance_spec_for_saving!(instance_spec)
          expect(prepared_spec['env']).to eq({'a' => '((a_placeholder))'})
          expect(prepared_spec.key?('uninterpolated_properties')).to be_falsey
        end
      end

      context 'when config server is disabled' do
        before do
          allow(Bosh::Director::Config).to receive(:config_server_enabled).and_return(false)
        end

        it 'does not set uninterpolated properties to properties' do
          prepared_spec = InstanceModelHelper.prepare_instance_spec_for_saving!(instance_spec)
          expect(prepared_spec['properties']).to eq({'name'=>'a'})
          expect(prepared_spec.key?('uninterpolated_properties')).to be_falsey
        end

        it 'does not set links uninterpolated properties to properties' do
          prepared_spec = InstanceModelHelper.prepare_instance_spec_for_saving!(instance_spec)
          expect(prepared_spec['links']['link_name']['properties']).to eq({'a' => 'a_value',
                                                                           'b' => 'b_value',
                                                                           'c' => 'c_value'})
          expect(prepared_spec['links']['link_name'].key?('uninterpolated_properties')).to be_falsey
        end

        it 'does not set env uninterpolated values to env' do
          prepared_spec = InstanceModelHelper.prepare_instance_spec_for_saving!(instance_spec)
          expect(prepared_spec['env']).to eq({'a' => 'a_value'})
          expect(prepared_spec.key?('uninterpolated_env')).to be_falsey
        end
      end
    end

    describe '#adjust_instance_spec_after_retrieval!' do
      let(:link_raw_properties) do
        {
          'a' => '((a_placeholder))',
          'b' => '((b_placeholder))',
          'c' => 'c_value'
        }
      end

      let(:link_resolved_properties) do
        {
          'a' => 'a_value',
          'b' => 'b_value',
          'c' => 'c_value'
        }
      end

      let(:retrieved_spec) do
        {
          'properties' => {'name' => '((name_placeholder))'},
          'env' => {'env_name' => '((env_name_placeholder))'},
          'links' => {
            'link_name' => {
              'instances' => [{
                                'name' => 'external_db',
                                'address' => '192.168.15.4'
                              }],
              'properties' => link_raw_properties
            }
          }
        }
      end

      context 'when config server is enabled' do
        before do
          allow(Bosh::Director::Config).to receive(:config_server_enabled).and_return(true)
          expect(Bosh::Director::ConfigServer::ConfigParser).to receive(:parse).with({'name' => '((name_placeholder))'}).and_return({'name' => 'Big papa smurf'}).once
          expect(Bosh::Director::ConfigServer::ConfigParser).to receive(:parse).with({'env_name' => '((env_name_placeholder))'}).and_return({'env_name' => 'Happy smurf'}).once
          expect(Bosh::Director::ConfigServer::ConfigParser).to receive(:parse).with(link_raw_properties).and_return(link_resolved_properties).once
        end

        it 'resolves spec properties and populates uninterpolated props' do
          result = InstanceModelHelper.adjust_instance_spec_after_retrieval!(retrieved_spec)
          expect(result['properties']).to eq({'name'=>'Big papa smurf'})
          expect(result['uninterpolated_properties']).to eq({'name'=>'((name_placeholder))'})
        end

        it 'resolves spec env and populates uninterpolated envs' do
          result = InstanceModelHelper.adjust_instance_spec_after_retrieval!(retrieved_spec)
          expect(result['env']).to eq({'env_name'=>'Happy smurf'})
          expect(result['uninterpolated_env']).to eq({'env_name'=>'((env_name_placeholder))'})
        end

        it 'resolves links properties and populates uninterpolated props' do
          result = InstanceModelHelper.adjust_instance_spec_after_retrieval!(retrieved_spec)
          expect(result['links']['link_name']['properties']).to eq(link_resolved_properties)
          expect(result['links']['link_name']['uninterpolated_properties']).to eq(link_raw_properties)
        end
      end

      context 'when config server is disabled' do
        before do
          allow(Bosh::Director::Config).to receive(:config_server_enabled).and_return(false)
        end

        it 'does not resolve properties but it populates uninterpolated props' do
          result = InstanceModelHelper.adjust_instance_spec_after_retrieval!(retrieved_spec)
          expect(result['properties']).to eq({'name'=>'((name_placeholder))'})
          expect(result['uninterpolated_properties']).to eq({'name'=>'((name_placeholder))'})
        end

        it 'does not resolve env but it populates uninterpolated env' do
          result = InstanceModelHelper.adjust_instance_spec_after_retrieval!(retrieved_spec)
          expect(result['env']).to eq({'env_name'=>'((env_name_placeholder))'})
          expect(result['uninterpolated_env']).to eq({'env_name'=>'((env_name_placeholder))'})
        end

        it 'does not resolve links properties but it populates uninterpolated props' do
          result = InstanceModelHelper.adjust_instance_spec_after_retrieval!(retrieved_spec)
          expect(result['links']['link_name']['properties']).to eq(link_raw_properties)
          expect(result['links']['link_name']['uninterpolated_properties']).to eq(link_raw_properties)
        end
      end

    end

  end
end
