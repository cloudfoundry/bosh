require 'spec_helper'

module Bosh::Director::Models
  describe RuntimeConfig do
    let(:runtime_config_model) { RuntimeConfig.make(raw_manifest: mock_manifest) }
    let(:mock_manifest) { {name: '((manifest_name))'} }
    let(:new_runtime_config) { {name: 'runtime manifest'} }
    let(:deployment_name) { 'some_deployment_name' }

    describe "#raw_manifest" do
      it 'returns raw result' do
        expect(runtime_config_model.raw_manifest).to eq(mock_manifest)
      end
    end

    describe '#latest_set' do
      it 'returns the list of latest runtime configs grouped by name' do
        moop1 = Bosh::Director::Models::RuntimeConfig.new(properties: 'super_shiny: moop1', name: 'moop').save
        default = Bosh::Director::Models::RuntimeConfig.new(properties: 'super_shiny: default', name: '').save
        moop2 = Bosh::Director::Models::RuntimeConfig.new(properties: 'super_shiny: moop2', name: 'moop').save
        smurf_1 = Bosh::Director::Models::RuntimeConfig.new(properties: 'super_shiny: smurf_1', name: 'smurf').save
        smurf_2 = Bosh::Director::Models::RuntimeConfig.new(properties: 'super_shiny: smurf_2', name: 'smurf').save

        expect(Bosh::Director::Models::RuntimeConfig.latest_set).to contain_exactly(moop2, default, smurf_2)
      end

      it 'returns empty list when there are no records' do
        expect(Bosh::Director::Models::RuntimeConfig.latest_set).to be_empty()
      end
    end

    describe '#find_by_ids' do
      it 'returns all records that match ids' do
        runtime_configs = [
          Bosh::Director::Models::RuntimeConfig.new(properties: 'super_shiny: rc_1', name: 'rc_1').save,
          Bosh::Director::Models::RuntimeConfig.new(properties: 'super_shiny: rc_2', name: 'rc_2').save,
          Bosh::Director::Models::RuntimeConfig.new(properties: 'super_shiny: rc_3', name: 'rc_3').save
        ]

        expect(Bosh::Director::Models::RuntimeConfig.find_by_ids(runtime_configs.map(&:id))).to eq(runtime_configs)
      end

      it 'returns empty array when passed nil' do
        expect(Bosh::Director::Models::RuntimeConfig.find_by_ids(nil)).to eq([])
      end

      it 'returns empty array when passed none array parameter' do
        expect(Bosh::Director::Models::RuntimeConfig.find_by_ids('whatever')).to eq([])
      end
    end
  end
end