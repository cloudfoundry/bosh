require 'spec_helper'

require 'bosh/stemcell/archive_filename'
require 'bosh/stemcell/infrastructure'

module Bosh::Stemcell
  describe ArchiveFilename do
    let(:version) { '007' }
    let(:infrastructure) do
      instance_double('Bosh::Stemcell::Infrastructure::Base',
                      name: 'INFRASTRUCTURE',
                      hypervisor: 'HYPERVISOR')
    end

    subject(:archive_filename) do
      ArchiveFilename.new(version, infrastructure, 'FAKE_NAME', light)
    end

    describe '#to_s' do
      context 'when stemcell is NOT light' do
        let(:light) { false }

        it 'includes name, version, infrastructure name, infrastructure hypervisor' do
          expect(archive_filename.to_s).to eq ('FAKE_NAME-007-INFRASTRUCTURE-HYPERVISOR-ubuntu.tgz')
        end
      end

      context 'when stemcell is light' do
        let(:light) { true }

        it 'prefixes the name with "light-"' do
          expect(archive_filename.to_s).to eq ('light-FAKE_NAME-007-INFRASTRUCTURE-HYPERVISOR-ubuntu.tgz')
        end
      end
    end
  end
end
