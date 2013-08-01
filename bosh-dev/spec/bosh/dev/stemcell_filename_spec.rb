require 'spec_helper'

require 'bosh/dev/stemcell_filename'

module Bosh
  module Dev
    describe StemcellFilename do
      describe 'building a stemcell name' do

        let(:options) do
          {
              name: 'micro_stemcell',
              version: '123',
              infrastructure: 'aws',
              format: 'ami',
              hypervisor: 'dos',
              arch: 'arm6',
              distro: 'gentoo'
          }
        end

        subject(:filename) { StemcellFilename.new(options) }

        context 'with all of the parameters' do
          its(:filename) { should eq('micro_stemcell-123-aws-ami-dos-arm6-gentoo.tgz') }
        end

        context 'when one of the required fields is missing' do
          let(:options) do
            {
                name: 'micro_stemcell',
                infrastructure: 'aws',
                format: 'ami',
                hypervisor: 'dos',
                arch: 'arm6',
                distro: 'gentoo'
            }
          end

          it 'raises an error' do
            expect {
              filename.filename
            }.to raise_error(KeyError, /version/)
          end
        end

        context 'when the name is not provided' do

          let(:options) do
            {
                version: '123',
                infrastructure: 'aws',
                format: 'ami',
                hypervisor: 'dos',
                arch: 'arm6',
                distro: 'gentoo'
            }
          end

          it 'uses "stemcell" for the name' do
            expect(filename.filename).to eq('stemcell-123-aws-ami-dos-arm6-gentoo.tgz')
          end
        end

        context 'when the arch is not provided' do

          let(:options) do
            {
                name: 'micro_stemcell',
                version: '123',
                infrastructure: 'aws',
                format: 'ami',
                hypervisor: 'dos',
                distro: 'gentoo'
            }
          end

          it 'uses "amd64" for the arch' do
            expect(filename.filename).to eq('micro_stemcell-123-aws-ami-dos-amd64-gentoo.tgz')
          end
        end

        context 'when the distro is not provided' do

          let(:options) do
            {
                name: 'micro_stemcell',
                version: '123',
                infrastructure: 'aws',
                format: 'ami',
                hypervisor: 'dos',
                arch: 'arm6'
            }
          end

          it 'uses "ubuntu_lucid" for the arch' do
            expect(filename.filename).to eq('micro_stemcell-123-aws-ami-dos-arm6-ubuntu_lucid.tgz')
          end
        end

      end
    end
  end
end