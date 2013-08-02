require 'bosh/stemcell/archive_filename'
require 'bosh/dev/infrastructure'

module Bosh
  module Stemcell
    describe ArchiveFilename do
      subject(:archive_filename) do
        ArchiveFilename.new(version, infrastructure, 'bosh-stemcell', light)
      end

      describe '#to_s' do

        context 'when stemcell is light' do
          let(:light) { true }
          let(:infrastructure) { Bosh::Dev::Infrastructure::Vsphere.new }

          context 'and the version is a build number' do
            let(:version) { 123 }
            it 'prepends light before name' do
              expect(archive_filename.to_s).to eq ('light-bosh-stemcell-vsphere-123.tgz')
            end
          end

          context 'and the version is latest' do
            let(:version) { 'latest' }

            it 'appends light after latest' do
              expect(archive_filename.to_s).to eq ('latest-light-bosh-stemcell-vsphere.tgz')
            end
          end
        end

        context 'when stemcell is not light' do
          let(:light) { false }
          context 'when the infrastructure has a hypervisor' do
            let(:infrastructure) { Bosh::Dev::Infrastructure::OpenStack.new }

            context 'and the version is a build number' do
              let(:version) { 123 }

              it 'ends with the infrastructure, hypervisor and build number' do
                expect(archive_filename.to_s).to eq('bosh-stemcell-openstack-kvm-123.tgz')
              end
            end

            context 'and the version is latest' do
              let(:version) { 'latest' }

              it 'begins with latest and ends with the infrastructure' do
                expect(archive_filename.to_s).to eq('latest-bosh-stemcell-openstack.tgz')
              end
            end
          end

          context 'when the infrastructure does not have a hypervisor' do
            let(:infrastructure) { Bosh::Dev::Infrastructure::Aws.new }

            context 'and the version is a build number' do
              let(:version) { 123 }

              it 'ends with the infrastructure and build number' do
                expect(archive_filename.to_s).to eq('bosh-stemcell-aws-123.tgz')
              end
            end

            context 'and the version is latest' do
              let(:version) { 'latest' }

              it 'begins with latest and ends with the infrastructure' do
                expect(archive_filename.to_s).to eq('latest-bosh-stemcell-aws.tgz')
              end
            end
          end
        end
      end
    end
  end
end
