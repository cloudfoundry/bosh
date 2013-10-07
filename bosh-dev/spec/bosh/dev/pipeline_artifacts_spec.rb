require 'spec_helper'
require 'bosh/dev/pipeline_artifacts'

module Bosh
  module Dev
    describe PipelineArtifacts do
      let(:operating_system) { instance_double('Bosh::Stemcell::OperatingSystem::Ubuntu', name: 'ubuntu') }
      let(:infrastructure) { instance_double('Bosh::Stemcell::Infrastructure::Aws', name: 'fake', light?: false) }
      let(:version) { 123 }
      subject(:artifacts) { described_class.new(version) }

      before do
        Bosh::Stemcell::OperatingSystem.stub(:for).with('ubuntu').and_return(operating_system)
        Bosh::Stemcell::Infrastructure.stub(:all).and_return([infrastructure])
      end

      describe '#list' do
        it 'returns a complete list of stemcell build artifact names' do
          Bosh::Stemcell::ArchiveFilename.stub(:new).with(
            'latest', infrastructure, operating_system, 'bosh-stemcell', false).and_return('fake-latest-archive-filename')
          Bosh::Stemcell::ArchiveFilename.stub(:new).with(
            version, infrastructure, operating_system, 'bosh-stemcell', false).and_return("fake-#{version}-archive-filename")

          expected_list = %w[
            bosh-stemcell/fake/fake-123-archive-filename
            bosh-stemcell/fake/fake-latest-archive-filename
          ].sort

          expect(artifacts.list.sort).to eq(expected_list)
        end

        context 'infrastructure is light capable' do
          let(:infrastructure) { instance_double('Bosh::Stemcell::Infrastructure::Aws', name: 'fake', light?: true) }

          it 'returns artifact filenames for both light and regular stemcells' do
            Bosh::Stemcell::ArchiveFilename.stub(:new).with(
              'latest', infrastructure, operating_system, 'bosh-stemcell', true).and_return('light-fake-latest-archive-filename')
            Bosh::Stemcell::ArchiveFilename.stub(:new).with(
              version, infrastructure, operating_system, 'bosh-stemcell', true).and_return("light-fake-#{version}-archive-filename")
            Bosh::Stemcell::ArchiveFilename.stub(:new).with(
              'latest', infrastructure, operating_system, 'bosh-stemcell', false).and_return('fake-latest-archive-filename')
            Bosh::Stemcell::ArchiveFilename.stub(:new).with(
              version, infrastructure, operating_system, 'bosh-stemcell', false).and_return("fake-#{version}-archive-filename")

            expected_list = %w[
              bosh-stemcell/fake/light-fake-123-archive-filename
              bosh-stemcell/fake/light-fake-latest-archive-filename
              bosh-stemcell/fake/fake-123-archive-filename
              bosh-stemcell/fake/fake-latest-archive-filename
            ].sort

            expect(artifacts.list.sort).to eq(expected_list)
          end
        end

        context 'multiple infrastructures are returned if specified' do
          it 'returns artifact filenames for all infrastructures' do
            Bosh::Stemcell::Infrastructure.stub(:all).and_return([infrastructure, infrastructure])
            Bosh::Stemcell::ArchiveFilename.stub(:new).with(
              'latest', infrastructure, operating_system, 'bosh-stemcell', false).and_return('fake-latest-archive-filename')
            Bosh::Stemcell::ArchiveFilename.stub(:new).with(
              version, infrastructure, operating_system, 'bosh-stemcell', false).and_return("fake-#{version}-archive-filename")

            expected_list = %w[
              bosh-stemcell/fake/fake-123-archive-filename
              bosh-stemcell/fake/fake-123-archive-filename
              bosh-stemcell/fake/fake-latest-archive-filename
              bosh-stemcell/fake/fake-latest-archive-filename
            ].sort

            expect(artifacts.list.sort).to eq(expected_list)
          end
        end
      end
    end
  end
end
