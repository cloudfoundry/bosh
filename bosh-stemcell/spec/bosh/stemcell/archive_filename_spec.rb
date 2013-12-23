require 'spec_helper'
require 'bosh/stemcell/archive_filename'
require 'bosh/stemcell/infrastructure'
require 'bosh/stemcell/operating_system'

module Bosh::Stemcell
  describe ArchiveFilename do
    let(:version) { '007' }
    let(:infrastructure) do
      instance_double('Bosh::Stemcell::Infrastructure::Base',
                      name: 'INFRASTRUCTURE',
                      hypervisor: 'HYPERVISOR')
    end
    let(:operating_system) do
      instance_double('Bosh::Stemcell::OperatingSystem::Base',
                      name: 'OPERATING_SYSTEM')
    end

    subject(:archive_filename) do
      ArchiveFilename.new(version, infrastructure, operating_system, 'FAKE_NAME', light)
    end

    describe '#to_s' do
      context 'when stemcell is NOT light' do
        let(:light) { false }

        it 'includes name, version, infrastructure name, infrastructure hypervisor' do
          expect(archive_filename.to_s).to eq ('FAKE_NAME-007-INFRASTRUCTURE-HYPERVISOR-OPERATING_SYSTEM.tgz')
        end
      end

      context 'when stemcell is light' do
        let(:light) { true }

        it 'prefixes the name with "light-"' do
          expect(archive_filename.to_s).to eq ('light-FAKE_NAME-007-INFRASTRUCTURE-HYPERVISOR-OPERATING_SYSTEM.tgz')
        end
      end

      context 'when stemcell has ruby agent' do
        it 'does not include the agent name in the archive name' do
          archive_filename = ArchiveFilename.new(version, infrastructure, operating_system, 'FAKE_NAME', false, 'ruby')
          expect(archive_filename.to_s).to eq ('FAKE_NAME-007-INFRASTRUCTURE-HYPERVISOR-OPERATING_SYSTEM.tgz')
        end
      end

      context 'when stemcell has go agent' do
        it 'includes go_agent in the archive name' do
          archive_filename = ArchiveFilename.new(version, infrastructure, operating_system, 'FAKE_NAME', false, 'go')
          expect(archive_filename.to_s).to eq ('FAKE_NAME-007-INFRASTRUCTURE-HYPERVISOR-OPERATING_SYSTEM-go_agent.tgz')
        end
      end
    end
  end
end
