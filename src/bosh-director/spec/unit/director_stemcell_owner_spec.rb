require 'spec_helper'

module Bosh::Director
  describe DirectorStemcellOwner do
    subject { DirectorStemcellOwner.new }

    before do
      allow(Etc).to receive(:uname).and_return({ version: version_string })
    end

    let(:version_string) { '#35~16.04.1-Ubuntu SMP Fri Aug 10 21:54:34 UTC 2018' }

    describe '#stemcell_os' do
      context 'trusty' do
        let(:version_string) { '#35~14.04.1-Ubuntu SMP Fri Aug 10 21:54:34 UTC 2018' }

        it 'should be ubuntu-trusty' do
          expect(subject.stemcell_os).to eq('ubuntu-trusty')
        end
      end

      context 'xenial' do
        let(:version_string) { '#35~16.04.1-Ubuntu SMP Fri Aug 10 21:54:34 UTC 2018' }

        it 'should be ubuntu-xenial' do
          expect(subject.stemcell_os).to eq('ubuntu-xenial')
        end
      end

      context 'bionic' do
        let(:version_string) { '#35~18.04.1-Ubuntu SMP Fri Aug 10 21:54:34 UTC 2018' }

        it 'should be ubuntu-bionic' do
          expect(subject.stemcell_os).to eq('ubuntu-bionic')
        end
      end

      context 'other ubuntu' do
        let(:version_string) { '#35~12.04.1-Ubuntu SMP Fri Aug 10 21:54:34 UTC 2018' }

        it 'should be the raw number' do
          expect(subject.stemcell_os).to eq('ubuntu-12.04.1')
        end
      end

      context 'other' do
        let(:version_string) { 'some random version string' }

        it 'should be a dash' do
          expect(subject.stemcell_os).to eq('-')
        end
      end
    end

    describe '#stemcell_version' do
      context 'that file is actually there' do
        before do
          allow(File).to receive(:read).with('/var/vcap/bosh/etc/stemcell_version').and_return("123.45\n")
          allow(File).to receive(:exist?).with('/var/vcap/bosh/etc/stemcell_version').and_return(true)
        end

        it 'returns the stemcell_version specified in the config' do
          expect(subject.stemcell_version).to eq('123.45')
        end
      end

      context 'there is no file' do
        before do
          allow(File).to receive(:exist?).with('/var/vcap/bosh/etc/stemcell_version').and_return(false)
        end

        it 'returns -' do
          expect(subject.stemcell_version).to eq('-')
        end
      end

      context 'the file is removed while running' do
        before do
          allow(File).to receive(:read).with('/var/vcap/bosh/etc/stemcell_version').and_return("123.45\n")
          allow(File).to receive(:exist?).with('/var/vcap/bosh/etc/stemcell_version').and_return(true)
        end

        it 'returns the stemcell_version specified in the config' do
          expect(subject.stemcell_version).to eq('123.45')

          allow(File).to receive(:exist?).with('/var/vcap/bosh/etc/stemcell_version').and_return(false)

          expect(subject.stemcell_version).to eq('123.45')
        end
      end
    end
  end
end
