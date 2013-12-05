require 'spec_helper'

describe Bosh::Cli::Stemcell do
  describe '#perform_validation' do
    context 'with a valid stemcell' do
      let(:subject) { described_class.new(valid_stemcell) }
      let(:valid_stemcell) { spec_asset('valid_stemcell.tgz') }
      let(:valid_stemcell_manifest) {
        { 'name' => 'ubuntu-stemcell',
          'version' => 1,
          'cloud_properties' => {
            'property1' => 'test',
            'property2' => 'test'
          }
        }
      }

      it 'reads the mainfest_yaml file' do
        expect { subject.perform_validation }.to change { subject.manifest }.from(nil).to(valid_stemcell_manifest)
      end

      it 'reports a valid stemcell' do
        expect(subject.perform_validation).to be(true)
      end
    end

    context 'with a non-existant stemcell' do
      let(:subject) { described_class.new(missing_stemcell) }
      let(:missing_stemcell) { '/dev/null' }

      it 'raises a Zlib::GzipFile error' do
        expect { subject.perform_validation }.to raise_error(Zlib::GzipFile::Error)
      end
    end

    context 'with missing manifest' do
      let(:subject) { described_class.new(missing_mf_stemcell) }
      let(:missing_mf_stemcell) { spec_asset('stemcell_missing_mf.tgz') }

      it 'halts validation' do
        expect { subject.perform_validation }.to raise_error(Bosh::Cli::ValidationHalted)
      end
    end

    context 'with a missing image file' do
      let(:subject) { described_class.new(no_image_stemcell) }
      let(:no_image_stemcell) { spec_asset('stemcell_no_image.tgz') }

      it 'halts validation' do
        expect { subject.perform_validation }.to raise_error(Bosh::Cli::ValidationHalted)
      end
    end

    context 'with an invalid manifest' do
      let(:subject) { described_class.new(invalid_mf_stemcell) }
      let(:invalid_mf_stemcell) { spec_asset('stemcell_invalid_mf.tgz') }

      it 'halts validation' do
        expect { subject.perform_validation }.to raise_error(Bosh::Cli::ValidationHalted)
      end
    end
  end
end
