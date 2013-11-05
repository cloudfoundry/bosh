require 'spec_helper'
require 'bosh/dev/version_file'

module Bosh::Dev
  describe VersionFile do
    around do |example|
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) { example.call }
      end
    end

    describe '#initialize' do
      context 'when the BOSH_VERSION file exists' do
        before { FileUtils.touch(described_class::BOSH_VERSION_FILE) }

        it 'raises an ArgumentError if version_number is nil' do
          expect {
            described_class.new(nil)
          }.to raise_error(ArgumentError, 'Version number must be specified.')
        end

        it 'sets #version_number' do
          number = described_class.new('FAKE_NUMBER').version_number
          expect(number).to eq('FAKE_NUMBER')
        end
      end

      context 'when the BOSH_VERSION file doest not exist' do
        it 'raises an error' do
          expect {
            described_class.new('1234')
          }.to raise_error('BOSH_VERSION must exist')
        end
      end
    end

    describe '#write' do
      subject { described_class.new('1234') }

      context 'when existing version ends with an integer' do
        before { File.write(described_class::BOSH_VERSION_FILE, "1.5.0.pre.3\n") }

        it 'updates BOSH_VERSION with the :version_number' do
          expect {
            subject.write
          }.to change { subject.version }.from('1.5.0.pre.3').to('1.5.0.pre.1234')
        end
      end

      context 'when existing version ends with local' do
        before { File.write(described_class::BOSH_VERSION_FILE, "1.5.0.pre.local\n") }

        it 'updates BOSH_VERSION with the :version_number' do
          expect {
            subject.write
          }.to change { subject.version }.from('1.5.0.pre.local').to('1.5.0.pre.1234')
        end
      end
    end
  end
end
