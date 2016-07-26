require 'spec_helper'

module Bosh::Director
  describe InstanceDecorator do
    describe '#lifecycle' do
      let(:instance_groups) {
        [{
            'name' => 'job-1',
            'lifecycle' => lifecycle,
            'instances' => 1,
            'jobs' => [],
            'vm_type' => 'm1.small',
            'stemcell' => 'stemcell',
            'networks' => [{'name' => 'network'}]
         }]
      }

      let(:manifest) {
        {
            'name' => 'something',
            'releases' => [],'instance_groups' => instance_groups,
            'update' => {
                'canaries' => 1,
                'max_in_flight' => 1,
                'canary_watch_time' => 20,
                'update_watch_time' => 20
            },
            'stemcells' => [{
                'name' => 'stemcell',
                'alias' => 'stemcell'
                            }]
        }
      }

      let(:cloud_config_hash) {
        {
            'compilation' => {
                'network' => 'network',
                'workers' => 1
            },
            'networks' => [{
                               'name' => 'network',
                               'subnets' => []

                           }],
            'vm_types' => [{
                              'name' => 'm1.small'
                          }]

        }
      }
      let(:manifest_text) { manifest.to_yaml }
      let(:cloud_config) { Models::CloudConfig.make(manifest: cloud_config_hash) }
      let(:deployment) { Models::Deployment.make(name: 'deployment', manifest: manifest_text, cloud_config: cloud_config) }
      let(:instance) { Models::Instance.make(deployment: deployment, job: 'job-1') }

      context "when lifecycle is 'service'" do
        let(:lifecycle) { 'service' }
        it "returns 'service'" do
          expect(InstanceDecorator.new(instance).lifecycle).to eq('service')
        end
      end

      context "when lifecycle is 'errand'" do
        let(:lifecycle) { 'errand' }
        it "returns 'errand'" do
          expect(InstanceDecorator.new(instance).lifecycle).to eq('errand')
        end
      end

      context 'when no manifest is stored in the database' do
        let(:manifest_text) { nil }
        it "returns 'nil'" do
          expect(InstanceDecorator.new(instance).lifecycle).to be_nil
        end
      end
    end
  end
end