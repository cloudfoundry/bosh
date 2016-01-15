require 'spec_helper'

module Bosh::Cli
  describe ReleaseArchiver do
    subject(:archiver) do
      ReleaseArchiver.new(release_source.join('release-123.tgz'), manifest, packages, jobs, license)
    end
    let(:release_source) { Support::FileHelpers::ReleaseDirectory.new }
    let(:manifest) { release_source.add_file(nil, 'release.MF', 'contents') }
    let(:custom_file_mode) { nil }
    let(:packages) do
      [].tap do |result|
        result << artifact('package-one')
        result << artifact('package-two')
      end
    end
    let(:jobs) do
      [].tap do |result|
        result << artifact('job-one')
        result << artifact('job-two')
      end
    end
    let(:license) do
      artifact('license') do |tarball|
        tarball.add_file('LICENSE', 'license content')
        tarball.add_file('NOTICE', 'notice content')
      end
    end

    describe "#build" do
      let(:listing) do
        list_tar_files(archiver.filepath)
      end

      it "includes the manifest" do
        archiver.build
        expect(listing).to include('./release.MF')
      end

      it "includes the package tarballs" do
        archiver.build
        expect(listing).to include('./packages/package-one.tgz')
        expect(listing).to include('./packages/package-two.tgz')
      end

      it "includes the job tarballs" do
        archiver.build
        expect(listing).to include('./jobs/job-one.tgz')
        expect(listing).to include('./jobs/job-two.tgz')
      end

      it "includes the license text files" do
        archiver.build
        expect(listing).to include('./LICENSE')
        expect(listing).to include('./NOTICE')
      end

      it "excludes license tarball" do
        archiver.build
        expect(listing).to_not include('./license.tgz')
      end

      context "given custom file modes" do
        let(:custom_file_mode) { 0400 }

        it "preserves those" do
          archiver.build

          dir = Dir.mktmpdir
          Dir.chdir(dir) do
            extract_tar_files(archiver.filepath)
            listing.reject { |filename| ["./LICENSE", "./NOTICE", "./release.MF"].include?(filename)}.each do |entry|
              expect(file_mode(File.join(dir, entry))).to eq('0400')
            end
          end
        end
      end

      context "when no license is provided" do
        let(:license) { nil }

        it "succeeds" do
          expect { archiver.build }.to_not raise_error
        end
      end
    end

    def artifact(name, &block)
      path = release_source.add_tarball("#{name}.tgz", &block).path
      File.chmod(custom_file_mode, path) if custom_file_mode

      BuildArtifact.new(name, "#{name}-fingerprint", path, "#{name}-sha1", [], false, false)
    end
  end
end
