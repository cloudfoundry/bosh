require 'spec_helper'
require 'bosh/dev/stemcell_artifact'
require 'bosh/stemcell/definition'
require 'bosh/stemcell/infrastructure'

module Bosh::Dev
  describe StemcellArtifact do

    subject(:stemcell_artifact) { StemcellArtifact.new(source_version, destination_version, stemcell_definition, logger, 'fake-disk-format') }

    let(:stemcell_definition) { instance_double('Bosh::Stemcell::Definition', infrastructure: infrastructure) }
    let(:infrastructure) { double('Bosh::Stemcell::Infrastructure::Fake', name: infrastructure_name) }
    let(:infrastructure_name) { 'fake-infrastructure-name' }
    let(:source_version) { 'fake-source-version' }
    let(:destination_version) { 'fake-destination-version' }

    let(:archive_source_filename) { instance_double('Bosh::Stemcell::ArchiveFilename', to_s: archive_source_filename_string) }
    let(:archive_source_filename_string) { 'fake-source-filename.tgz' }
    let(:archive_destination_filename) { instance_double('Bosh::Stemcell::ArchiveFilename', to_s: archive_destination_filename_string) }
    let(:archive_destination_filename_string) { 'fake-destination-filename.tgz' }
    before do
      allow(Bosh::Stemcell::ArchiveFilename).to receive(:new).
        with(source_version, stemcell_definition, 'bosh-stemcell', 'fake-disk-format').
        and_return(archive_source_filename)

      allow(Bosh::Stemcell::ArchiveFilename).to receive(:new).
        with(destination_version, stemcell_definition, 'bosh-stemcell', 'fake-disk-format').
        and_return(archive_destination_filename)
    end

    describe '#name' do
      it 'returns the filename for the release' do
        expect(stemcell_artifact.name).to eq(archive_destination_filename_string)
      end
    end

    describe '#promote' do
      let(:source) { 'fake-stemcell-source' }
      let(:destination) { 'fake-stemcell-destination' }

      before do
        allow(UriProvider).to receive(:pipeline_s3_path).
          with("#{source_version}/bosh-stemcell/#{infrastructure_name}", archive_source_filename_string).
          and_return(source)

        allow(UriProvider).to receive(:artifacts_s3_path).
          with("bosh-stemcell/#{infrastructure_name}", archive_destination_filename_string).
          and_return(destination)
      end

      it 'copies the release from the pipeline to the artifacts bucket' do
        expect(Open3).to receive(:capture3).
          with("s3cmd --verbose cp #{source} #{destination}").
          and_return([ nil, nil, instance_double('Process::Status', success?: true) ])

        stemcell_artifact.promote
      end
    end

    describe '#promoted?' do
      context 'when destination version is not latest' do
        let(:destination) { 'fake-stemcell-destination' }

        before do
          allow(UriProvider).to receive(:artifacts_s3_path).
            with("bosh-stemcell/#{infrastructure_name}", stemcell_artifact.name).
            and_return(destination)
        end

        it 'returns true if the release file exists in the s3 bucket' do
          expect(Open3).to receive(:capture3).
            with("s3cmd info #{destination}").
            and_return([nil, nil, instance_double('Process::Status', success?: true)])

          expect(stemcell_artifact.promoted?).to be(true)
        end

        it 'returns false if the release file does not exists in the s3 bucket' do
          expect(Open3).to receive(:capture3).
            with("s3cmd info #{destination}").
            and_return([nil, 'fake-error', instance_double('Process::Status', success?: false)])

          expect(stemcell_artifact.promoted?).to be(false)
        end
      end

      context 'when destination version is latest' do
        let(:destination_version) { 'latest' }

        it 'returns false' do
          expect(Open3).to_not receive(:capture3)
          expect(stemcell_artifact.promoted?).to be(false)
        end
      end
    end
  end
end
