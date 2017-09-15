require 'spec_helper'

module Bosh::Director::Models
  describe CloudConfig do
    let(:cloud_config_model) { CloudConfig.make(raw_manifest: raw_manifest) }
    let(:raw_manifest) { {name: '((manifest_name))'} }
    let(:interpolated_manifest) { {name: 'cloud config manifest'} }
    let(:deployment_name) { 'some_deployment_name' }

    describe '#interpolated_manifest' do
      let(:variables_interpolator) { instance_double(Bosh::Director::ConfigServer::VariablesInterpolator) }

      before do
        allow(Bosh::Director::ConfigServer::VariablesInterpolator).to receive(:new).and_return(variables_interpolator)
        allow(variables_interpolator).to receive(:interpolate_cloud_manifest).with(raw_manifest, deployment_name).and_return(interpolated_manifest)
      end

      it 'returns interpolated manifest' do
        result = cloud_config_model.interpolated_manifest(deployment_name)
        expect(result).to eq(interpolated_manifest)
      end
    end

    describe '#raw_manifest' do
      it 'returns raw result' do
        expect(cloud_config_model.raw_manifest).to eq(raw_manifest)
      end
    end

  end
end