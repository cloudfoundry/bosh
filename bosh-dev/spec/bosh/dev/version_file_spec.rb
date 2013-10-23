require 'spec_helper'
require 'bosh/dev/version_file'

module Bosh::Dev
  describe VersionFile do
    around do |example|
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          example.call
        end
      end
    end

    before do
      File.write(VersionFile::BOSH_VERSION_FILE, "1.5.0.pre.3\n")
    end

    describe '#initialize' do
      it 'raises an ArgumentError if version_number is nil' do
        expect { VersionFile.new(nil) }.to raise_error(ArgumentError, 'Version number must be specified.')
      end

      it 'sets #version_number' do
        expect(VersionFile.new('FAKE_NUMBER').version_number).to eq('FAKE_NUMBER')
      end

      context 'when the BOSH_VERSION file doest not exist' do
        before do
          FileUtils.rm(VersionFile::BOSH_VERSION_FILE)
        end

        it 'raises an error' do
          expect { VersionFile.new('1234') }.to raise_error('BOSH_VERSION must exist')
        end
      end
    end

    describe '#write' do
      subject { VersionFile.new('1234') }

      it 'updates BOSH_VERSION with the :version_number' do
        expect {
          subject.write
        }.to change { subject.version }.from('1.5.0.pre.3').to('1.5.0.pre.1234')
      end
    end
  end
end
