require 'spec_helper'

module Bosh::Director
  describe DirectorStemcellOwner do
    subject { DirectorStemcellOwner.new }

    before do
      allow(File).to receive(:exist?).with('/var/vcap/bosh/etc/operating_system').and_return(operating_system_exists)
      allow(File).to receive(:read).with('/var/vcap/bosh/etc/operating_system').and_return(operating_system_content) if operating_system_exists
      allow(File).to receive(:exist?).with('/etc/os-release').and_return(os_release_exists)
      allow(File).to receive(:readlines).with('/etc/os-release').and_return(os_release_content) if os_release_exists
    end

    let(:operating_system_exists) { false }
    let(:operating_system_content) { '' }
    let(:os_release_exists) { false }
    let(:os_release_content) { [] }

    describe '#stemcell_os' do
      context 'when operating_system file exists' do
        let(:operating_system_exists) { true }
        let(:operating_system_content) { "ubuntu\n" }
        let(:os_release_exists) { true }

        context 'jammy' do
          let(:os_release_content) do
            <<~OS_RELEASE.lines
              NAME="Ubuntu"
              VERSION="22.04.1 LTS (Jammy Jellyfish)"
              ID=ubuntu
              UBUNTU_CODENAME=jammy
            OS_RELEASE
          end

          it 'should read os from operating_system file and codename from os-release' do
            expect(subject.stemcell_os).to eq('ubuntu-jammy')
          end
        end

        context 'noble' do
          let(:os_release_content) do
            <<~OS_RELEASE.lines
              NAME="Ubuntu"
              VERSION="24.04 LTS (Noble Numbat)"
              ID=ubuntu
              UBUNTU_CODENAME=noble
            OS_RELEASE
          end

          it 'should read os from operating_system file and codename from os-release' do
            expect(subject.stemcell_os).to eq('ubuntu-noble')
          end
        end
      end

      context 'when operating_system file does not exist but os-release does' do
        let(:operating_system_exists) { false }
        let(:os_release_exists) { true }

        context 'fallback to os-release for both os and codename' do
          let(:os_release_content) do
            <<~OS_RELEASE.lines
              NAME="Ubuntu"
              VERSION="22.04 LTS (Jammy Jellyfish)"
              ID=ubuntu
              UBUNTU_CODENAME=jammy
            OS_RELEASE
          end

          it 'should read both from os-release file' do
            expect(subject.stemcell_os).to eq('ubuntu-jammy')
          end
        end

        context 'os-release with bionic' do
          let(:os_release_content) do
            <<~OS_RELEASE.lines
              ID=ubuntu
              UBUNTU_CODENAME=bionic
            OS_RELEASE
          end

          it 'should be ubuntu-bionic' do
            expect(subject.stemcell_os).to eq('ubuntu-bionic')
          end
        end
      end

      context 'when neither file exists' do
        let(:operating_system_exists) { false }
        let(:os_release_exists) { false }

        it 'should return dash' do
          expect(subject.stemcell_os).to eq('-')
        end
      end

      context 'when os-release exists but has no codename' do
        let(:operating_system_exists) { false }
        let(:os_release_exists) { true }
        let(:os_release_content) do
          <<~OS_RELEASE.lines
            ID=ubuntu
            VERSION_ID="22.04"
          OS_RELEASE
        end

        it 'should return dash when codename is missing' do
          expect(subject.stemcell_os).to eq('-')
        end
      end
    end

    describe '#stemcell_version' do
      context 'that file is actually there' do
        before do
          allow(File).to receive(:read).with('/var/vcap/bosh/etc/stemcell_version').and_return("123.45\n")
          allow(File).to receive(:exist?).with('/var/vcap/bosh/etc/stemcell_version').and_return(true)
          allow(File).to receive(:exist?).with('/etc/os-release').and_call_original
        end

        it 'returns the stemcell_version specified in the config' do
          expect(subject.stemcell_version).to eq('123.45')
        end
      end

      context 'there is no file' do
        before do
          allow(File).to receive(:exist?).with('/var/vcap/bosh/etc/stemcell_version').and_return(false)
          allow(File).to receive(:exist?).with('/etc/os-release').and_call_original
        end

        it 'returns -' do
          expect(subject.stemcell_version).to eq('-')
        end
      end

      context 'the file is removed while running' do
        before do
          allow(File).to receive(:read).with('/var/vcap/bosh/etc/stemcell_version').and_return("123.45\n")
          allow(File).to receive(:exist?).with('/var/vcap/bosh/etc/stemcell_version').and_return(true)
          allow(File).to receive(:exist?).with('/etc/os-release').and_call_original
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
