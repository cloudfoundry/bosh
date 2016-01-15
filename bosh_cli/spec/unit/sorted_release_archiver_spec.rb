require 'spec_helper'

module Bosh::Cli
  describe SortedReleaseArchiver do
    subject(:archiver) { SortedReleaseArchiver.new(release_source.path) }

    let(:release_source) { Support::FileHelpers::ReleaseDirectory.new }
    before do
      release_source.add_dir('packages')
      release_source.add_file('packages', 'package-one.tgz')
      release_source.add_file('packages', 'package-two.tgz')

      release_source.add_file(nil, 'release.MF', 'contents')
      release_source.add_file(nil, 'LICENSE', 'contents')
      release_source.add_file(nil, 'NOTICE', 'contents')

      release_source.add_dir('jobs')
      release_source.add_file('jobs', 'job-one.tgz')
      release_source.add_file('jobs', 'job-two.tgz')
    end

    let(:destination_file) { Tempfile.new('sorted-release-archiver-spec') }
    after { FileUtils.rm_rf(destination_file.path) }

    it 'includes files in tar in correct order' do
      archiver.archive(destination_file.path)
      archived_files = list_tar_content(destination_file.path)
      expect(archived_files.size).to eq(9)
      expect(archived_files[0]).to eq('./release.MF')
      expect(archived_files[1]).to eq('./LICENSE')
      expect(archived_files[2]).to eq('./NOTICE')
      expect(archived_files[3]).to eq('./jobs/')
      expect(archived_files[4]).to match /.\/jobs\/job-.*\.tgz/
      expect(archived_files[5]).to match /.\/jobs\/job-.*\.tgz/
      expect(archived_files[6]).to eq('./packages/')
      expect(archived_files[7]).to match /.\/packages\/package-.*\.tgz/
      expect(archived_files[8]).to match /.\/packages\/package-.*\.tgz/
    end
  end
end
