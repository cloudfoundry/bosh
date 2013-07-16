require 'spec_helper'
require 'bosh/dev/version_file'

module Bosh
  module Dev
    describe VersionFile do
      describe '#initialize' do
        it 'sets #version_number' do
          expect(VersionFile.new('FAKE_NUMBER').version_number).to eq('FAKE_NUMBER')
        end
      end

      describe '#write' do
        subject { VersionFile.new('FAKE_NUMBER') }

        it 'updates BOSH_VERSION with the :version_number' do
          Dir.mktmpdir do
            File.write('BOSH_VERSION', "1.5.0.pre.3\n")
            expect(File.read('BOSH_VERSION')).to eq("1.5.0.pre.3\n")

            subject.write

            expect(File.read('BOSH_VERSION')).to eq("1.5.0.pre.FAKE_NUMBER\n")
          end
        end
      end
    end
  end
end
