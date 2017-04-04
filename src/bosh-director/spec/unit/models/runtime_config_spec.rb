require 'spec_helper'

module Bosh::Director::Models
  describe RuntimeConfig do
    let(:runtime_config_model) { RuntimeConfig.make(raw_manifest: mock_manifest) }
    let(:mock_manifest) { {name: '((manifest_name))'} }
    let(:new_runtime_config) { {name: 'runtime manifest'} }
    let(:deployment_name) { 'some_deployment_name' }

    describe "#interpolated_manifest_for_deployment" do
      let(:variables_interpolator) { instance_double(Bosh::Director::ConfigServer::VariablesInterpolator) }

      before do
        allow(Bosh::Director::ConfigServer::VariablesInterpolator).to receive(:new).and_return(variables_interpolator)
        allow(variables_interpolator).to receive(:interpolate_runtime_manifest).with(mock_manifest, deployment_name).and_return(new_runtime_config)
      end

      it 'calls manifest resolver and returns its result' do
        result = runtime_config_model.interpolated_manifest_for_deployment(deployment_name)
        expect(result).to eq(new_runtime_config)
      end
    end

    describe "#raw_manifest" do
      it 'returns raw result' do
        expect(runtime_config_model.raw_manifest).to eq(mock_manifest)
      end
    end

    describe '#tags' do
      let(:current_deployment) { instance_double(Bosh::Director::Models::Deployment)}
      let(:current_variable_set) { instance_double(Bosh::Director::Models::VariableSet)}

      before do
        allow(Bosh::Director::Models::Deployment).to receive(:[]).with(name: deployment_name).and_return(current_deployment)
        allow(current_deployment).to receive(:current_variable_set).and_return(current_variable_set)
      end

      context 'when there are no tags' do
        it 'returns an empty hash' do
          expect(runtime_config_model.tags(deployment_name)).to eq({})
        end
      end

      context 'when there are tags' do
        let(:mock_manifest) { {'tags' => {'my-tag' => 'best-value'}}}
        let(:uninterpolated_mock_manifest) { {'tags' => {'my-tag' => '((a_value))'}} }

        it 'returns interpolated values from the manifest' do
          allow(runtime_config_model).to receive(:interpolated_manifest_for_deployment).with(deployment_name).and_return({'tags' => {'my-tag' => 'something'}})
          expect(runtime_config_model.tags(deployment_name)).to eq({'my-tag' => 'something'})
        end

        it 'returns the tags from the manifest' do
          expect(runtime_config_model.tags(deployment_name)).to eq({'my-tag' => 'best-value'})
        end
      end
    end
  end
end