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
                      name: 'OPERATING_SYSTEM',
                      version: 'OPERATING_SYSTEM_VERSION',
      )
    end
    let(:agent) do
      instance_double(
        'Bosh::Stemcell::Agent::Go',
        name: 'go'
      )
    end
    let(:light) { false }
    let(:definition) do
      instance_double(
        'Bosh::Stemcell::Definition',
        stemcell_name: 'fake-stemcell-name',
        light?: light,
        infrastructure: instance_double('Bosh::Stemcell::Infrastructure::Base', default_disk_format: 'iso'),
      )
    end

    let(:disk_format) { 'iso' }
    subject(:archive_filename) do
      ArchiveFilename.new(version, definition, 'FAKE_NAME', disk_format)
    end

    describe '#to_s' do
      context 'when stemcell is NOT light' do
        let(:light) { false }

        it 'includes name, version, stemcell name' do
          if RbConfig::CONFIG['host_cpu'] == "powerpc64le"
            expect(archive_filename.to_s).to eq ('FAKE_NAME-ppc64le-007-fake-stemcell-name.tgz')
          else
            expect(archive_filename.to_s).to eq ('FAKE_NAME-007-fake-stemcell-name.tgz')
          end
        end
      end

      context 'when stemcell is light' do
        let(:light) { true }

        it 'prefixes the name with "light-"' do
          if RbConfig::CONFIG['host_cpu'] == "powerpc64le"
            expect(archive_filename.to_s).to eq ('FAKE_NAME-ppc64le-007-fake-stemcell-name.tgz')
          else
            expect(archive_filename.to_s).to eq ('light-FAKE_NAME-007-fake-stemcell-name.tgz')
          end
        end
      end
    end
  end
end
