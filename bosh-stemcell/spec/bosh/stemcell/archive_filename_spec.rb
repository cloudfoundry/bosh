require 'spec_helper'
require 'bosh/stemcell/archive_filename'
require 'bosh/stemcell/definition'

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
    let(:agent) do
      instance_double(
        'Bosh::Stemcell::Agent::Ruby',
        name: 'ruby'
      )
    end
    let(:definition) do
      instance_double(
        'Bosh::Stemcell::Definition',
        infrastructure: infrastructure,
        operating_system: operating_system,
        agent: agent,
      )
    end

    subject(:archive_filename) do
      ArchiveFilename.new(version, definition, 'FAKE_NAME', light)
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
        let(:agent) do
          instance_double(
            'Bosh::Stemcell::Agent::Ruby',
            name: 'ruby'
          )
        end
        it 'does not include the agent name in the archive name' do
          archive_filename = ArchiveFilename.new(version, definition, 'FAKE_NAME', false)
          expect(archive_filename.to_s).to eq ('FAKE_NAME-007-INFRASTRUCTURE-HYPERVISOR-OPERATING_SYSTEM.tgz')
        end
      end

      context 'when stemcell has go agent' do
        let(:agent) do
          instance_double(
            'Bosh::Stemcell::Agent::Go',
            name: 'go'
          )
        end
        it 'includes go_agent in the archive name' do
          archive_filename = ArchiveFilename.new(version, definition, 'FAKE_NAME', false)
          expect(archive_filename.to_s).to eq ('FAKE_NAME-007-INFRASTRUCTURE-HYPERVISOR-OPERATING_SYSTEM-go_agent.tgz')
        end
      end
    end
  end
end
