require 'spec_helper'

module Bosh::Director
  describe DeploymentModelHelper do
    describe '#prepare_deployment_links_spec_for_saving' do
      let(:properties) do
        {
          'listen_port'=> 9035,
          'name_space'=> {
            'prop_a'=> 'default',
            'fibonacci'=> '452'
          }
        }
      end

      let(:uninterpolated_properties) do
        {
          'listen_port'=> 9035,
          'name_space'=> {
            'prop_a'=> 'default',
            'fibonacci'=> '((fibonacci_placeholder))'
          }
        }
      end

      let(:instances) do
        [{
           'name'=> 'my_job',
           'index'=> 0,
           'bootstrap'=> true,
           'id'=> '536c194b-ba52-4d1c-ba31-b0772e83831f',
           'az'=> 'z1',
           'address'=> '192.168.1.2',
           'addresses'=> {
             'a'=> '192.168.1.2'
           }
         }]
      end

      let(:deployment_links_spec) do
        {
          'my_instance_group'=> {
            'my_job'=> {
              'my_link_name'=> {
                'my_link_type'=> {
                  'networks'=> ['a'],
                  'properties'=> properties,
                  'uninterpolated_properties'=> uninterpolated_properties,
                  'instances'=> instances
                }
              }
            }
          }
        }
      end

      context 'when config server is enabled' do
        before do
          allow(Bosh::Director::Config).to receive(:config_server_enabled).and_return(true)
        end

        it 'only keeps uninterpolated links properties' do
          prepared_spec = DeploymentModelHelper.prepare_deployment_links_spec_for_saving(deployment_links_spec)
          expect(
            prepared_spec['my_instance_group']['my_job']['my_link_name']['my_link_type']['properties']
          ).to eq(uninterpolated_properties)
          expect(
            prepared_spec['my_instance_group']['my_job']['my_link_name']['my_link_type'].key?('uninterpolated_properties')
          ).to be_falsey
        end
      end

      context 'when config server is disabled' do
        before do
          allow(Bosh::Director::Config).to receive(:config_server_enabled).and_return(false)
        end

        it 'does not set uninterpolated links properties to the regular properties' do
          prepared_spec = DeploymentModelHelper.prepare_deployment_links_spec_for_saving(deployment_links_spec)
          expect(
            prepared_spec['my_instance_group']['my_job']['my_link_name']['my_link_type']['properties']
          ).to eq(properties)
          expect(
            prepared_spec['my_instance_group']['my_job']['my_link_name']['my_link_type'].key?('uninterpolated_properties')
          ).to be_falsey
        end
      end
    end



    describe '#adjust_deployment_links_spec_after_retrieval' do
      let(:properties) do
        {
          'listen_port'=> 9035,
          'name_space'=> {
            'prop_a'=> 'default',
            'fibonacci'=> '452'
          }
        }
      end

      let(:uninterpolated_properties) do
        {
          'listen_port'=> 9035,
          'name_space'=> {
            'prop_a'=> 'default',
            'fibonacci'=> '((fibonacci_placeholder))'
          }
        }
      end

      let(:instances) do
        [{
           'name'=> 'my_job',
           'index'=> 0,
           'bootstrap'=> true,
           'id'=> '536c194b-ba52-4d1c-ba31-b0772e83831f',
           'az'=> 'z1',
           'address'=> '192.168.1.2',
           'addresses'=> {
             'a'=> '192.168.1.2'
           }
         }]
      end

      let(:retrieved_deployment_links_spec) do
        {
          'my_instance_group'=> {
            'my_job'=> {
              'my_link_name'=> {
                'my_link_type'=> {
                  'networks'=> ['a'],
                  'properties'=> uninterpolated_properties,
                  'instances'=> instances
                }
              }
            }
          }
        }
      end

      context 'when config server is enabled' do
        before do
          allow(Bosh::Director::Config).to receive(:config_server_enabled).and_return(true)
          expect(Bosh::Director::ConfigServer::ConfigParser).
            to receive(:parse).
               with(uninterpolated_properties).
               and_return(properties).
               once
        end

        it 'resolves links properties and populates uninterpolated props' do
          result = DeploymentModelHelper.adjust_deployment_links_spec_after_retrieval(retrieved_deployment_links_spec)

          expect(
            result['my_instance_group']['my_job']['my_link_name']['my_link_type']['properties']
          ).to eq(properties)

          expect(
            result['my_instance_group']['my_job']['my_link_name']['my_link_type']['uninterpolated_properties']
          ).to eq(uninterpolated_properties)
        end
      end

      context 'when config server is disabled' do
        before do
          allow(Bosh::Director::Config).to receive(:config_server_enabled).and_return(false)
        end

        it 'does not resolve links properties but it populates uninterpolated props' do
          result = DeploymentModelHelper.adjust_deployment_links_spec_after_retrieval(retrieved_deployment_links_spec)

          expect(
            result['my_instance_group']['my_job']['my_link_name']['my_link_type']['properties']
          ).to eq(uninterpolated_properties)

          expect(
            result['my_instance_group']['my_job']['my_link_name']['my_link_type']['uninterpolated_properties']
          ).to eq(uninterpolated_properties)
        end
      end

    end

  end
end
