require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe ReleaseVersionExportedFrom do
    let(:valid_spec) do
      {
        'os' => 'stemcell-os',
        'version' => '0.5.2',
      }
    end

    describe 'parse' do
      it 'parses os and version' do
        stemcell = ReleaseVersionExportedFrom.parse(valid_spec)

        expect(stemcell.os).to eq('stemcell-os')
        expect(stemcell.version).to eq('0.5.2')
      end

      it 'requires os' do
        expect do
          ReleaseVersionExportedFrom.parse('version' => '0.5.2')
        end.to raise_error(
          Bosh::Director::ValidationMissingField,
          "Required property 'os' was not specified in object ({\"version\"=>\"0.5.2\"})",
        )
      end

      it 'requires version' do
        expect do
          ReleaseVersionExportedFrom.parse('os' => 'stemcell-os')
        end.to raise_error(
          Bosh::Director::ValidationMissingField,
          "Required property 'version' was not specified in object ({\"os\"=>\"stemcell-os\"})",
        )
      end
    end

    describe 'compatible_with?' do
      let(:exported_from) do
        ReleaseVersionExportedFrom.parse(
          'os' => 'ubuntu-trusty',
          'version' => '123.2',
        )
      end

      context 'when the stemcell has the same os and major version' do
        let(:stemcell) do
          Stemcell.parse(
            'os' => 'ubuntu-trusty',
            'version' => '123.3',
          )
        end

        it 'is true' do
          expect(exported_from.compatible_with?(stemcell)).to eq(true)
        end
      end

      context 'when the stemcell different major version' do
        let(:stemcell) do
          Stemcell.parse(
            'os' => 'ubuntu-trusty',
            'version' => '124.3',
          )
        end

        it 'is false' do
          expect(exported_from.compatible_with?(stemcell)).to eq(false)
        end
      end

      context 'when the stemcell has the different os' do
        let(:stemcell) do
          Stemcell.parse(
            'os' => 'windows',
            'version' => exported_from.version,
          )
        end

        it 'is false' do
          expect(exported_from.compatible_with?(stemcell)).to eq(false)
        end
      end
    end
  end
end
