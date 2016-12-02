require 'spec_helper'

describe Bosh::Cli::Resources::License, 'dev build' do
  subject(:license) do
    Bosh::Cli::Resources::License.new(release_source.path)
  end

  let(:release_source) { Support::FileHelpers::ReleaseDirectory.new }

  before do
    release_source.add_file('jobs', 'fake-job')
    release_source.add_file(nil, 'LICENSE')
    release_source.add_file(nil, 'NOTICE')
  end

  after do
    release_source.cleanup
  end

  describe '.discover' do
    it 'returns an Array of License instances' do
      license = Bosh::Cli::Resources::License.discover(release_source.path)
      expect(license).to be_a(Array)
      expect(license.size).to eq(1)
      expect(license[0]).to be_a(Bosh::Cli::Resources::License)
    end
  end

  its(:name) { is_expected.to eq('license') }
  its(:plural_type) { is_expected.to eq('') }

  describe '#validate!' do
    context 'when LICENSE and NOTICE files are found' do
      it 'does not raise an exception' do
        expect { license.validate! }.to_not raise_error
      end
    end
  
    context 'when a LICENSE file is found' do
      before do
        release_source.remove_file(nil, 'NOTICE')
      end
  
      it 'does not raise an exception' do
        expect { license.validate! }.to_not raise_error
      end
    end

    context 'when a NOTICE file is found' do
      before do
        release_source.remove_file(nil, 'LICENSE')
      end
  
      it 'does not raise an exception' do
        expect { license.validate! }.to_not raise_error
      end
    end
  
    context 'when no LICENSE or NOTICE file is found' do
      before do
        release_source.remove_file(nil, 'LICENSE')
        release_source.remove_file(nil, 'NOTICE')
      end
  
      it 'raises an exception' do
        expect { license.validate! }.to raise_error(Bosh::Cli::MissingLicense,
          "Missing LICENSE or NOTICE in #{release_source.path}")
      end
    end
  end

  describe '#files' do
    let(:archive_dir) { release_source.path }
    let(:blobstore) { double('blobstore') }
    let(:release_options) { {dry_run: false, final: false } }

    context 'when LICENSE and NOTICE files are found' do
      it 'includes the LICENSE file' do
        expect(license.files).to contain_exactly(
          [release_source.join('LICENSE'), 'LICENSE'],
          [release_source.join('NOTICE'), 'NOTICE']
        )
      end
    end

    context 'when a LICENSE file is found' do
      before do
        release_source.remove_file(nil, 'NOTICE')
      end

      it 'does not raise an exception' do
        expect(license.files).to contain_exactly(
          [release_source.join('LICENSE'), 'LICENSE']
        )
      end
    end

    context 'when a NOTICE file is found' do
      before do
        release_source.remove_file(nil, 'LICENSE')
      end

      it 'does not raise an exception' do
        expect(license.files).to contain_exactly(
          [release_source.join('NOTICE'), 'NOTICE']
        )
      end
    end

    context 'when no LICENSE or NOTICE file is found' do
      before do
        release_source.remove_file(nil, 'LICENSE')
        release_source.remove_file(nil, 'NOTICE')
      end

      it 'is empty' do
        expect(license.files).to be_empty
      end
    end
  end

  describe '#format_fingerprint' do
    it 'formats fingerprint based on base file name and digest' do
      expect(
        license.format_fingerprint('fake-digest', '/fake-dir/fake-filename', 'fake-name', '0660')
      ).to eq('fake-filenamefake-digest')
    end
  end
end
