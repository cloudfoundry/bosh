require 'spec_helper'
require 'bosh/dev/version_file'

module Bosh::Dev
  describe VersionFile do
    describe '#initialize' do
      it 'raises an ArgumentError if version_number is nil' do
        expect { VersionFile.new(nil) }.to raise_error(ArgumentError, 'Version number must be specified.')
      end

      it 'sets #version_number' do
        expect(VersionFile.new('FAKE_NUMBER').version_number).to eq('FAKE_NUMBER')
      end
    end

    describe '#write' do
      subject { VersionFile.new('1234') }

      around do |example|
        Dir.mktmpdir do |tmpdir|
          Dir.chdir(tmpdir) do
            File.write(VersionFile::BOSH_VERSION_FILE, "1.5.0.pre.3\n")

            example.call
          end
        end
      end

      it 'updates BOSH_VERSION with the :version_number' do
        expect {
          subject.write
        }.to change { subject.version }.from('1.5.0.pre.3').to('1.5.0.pre.1234')
      end
    end
  end
end
