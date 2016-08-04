require 'spec_helper'
require 'bosh/director/models/instance'

module Bosh::Director::Models
  describe Deployment do
    subject { described_class.make(name: 'test-dep') }

    let(:link_spec) do
      {
        'networks'=> ['a'],
        'properties'=> {},
        'instances'=>[{
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
      }
    end

    let(:deployment_links_spec) do
      {
        'my_instance_group'=> {
          'my_job'=> {
            'my_link_name'=> {
              'my_link_type'=> link_spec
            }
          }
        }
      }
    end

    describe '#link_spec' do
      it 'calls adjust_deployment_links_spec_after_retrieval helper method after DB read' do
        subject.link_spec_json=JSON.generate(deployment_links_spec)
        expect(Bosh::Director::DeploymentModelHelper).to receive(:adjust_deployment_links_spec_after_retrieval).with(deployment_links_spec)
        subject.link_spec
      end
    end

    describe '#link_spec=' do
      it 'calls prepare_deployment_links_spec_for_saving helper method before saving' do
        expect(Bosh::Director::DeploymentModelHelper).to receive(:prepare_deployment_links_spec_for_saving).with(link_spec).and_return({})
        subject.link_spec=(link_spec)
      end
    end
  end
end
