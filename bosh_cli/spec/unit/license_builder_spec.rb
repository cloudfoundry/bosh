require 'spec_helper'

describe Bosh::Cli::LicenseBuilder, 'dev build' do
  let(:basedir) { nil }

  def make_builder(final = false)
    blobstore = double('blobstore')
    Bosh::Cli::LicenseBuilder.new(release_dir, final, blobstore)
  end

  describe 'copying package files' do
    let(:builder) { make_builder }

    before do
      release_dir.add_file(basedir, 'LICENSE')
      release_dir.add_file(basedir, 'NOTICE')
    end

    it 'copies the LICENSE file' do
      builder.copy_files
      expect(File).to exist(File.join(builder.build_dir, 'LICENSE'))
    end

    it 'copies the NOTICE file' do
      builder.copy_files
      expect(File).to exist(File.join(builder.build_dir, 'NOTICE'))
    end

    it 'does not copy non-relevant files' do
      release_dir.add_file(basedir, 'AUTHORS')
      builder.copy_files
      expect(File).to_not exist(File.join(builder.build_dir, 'AUTHORS'))
    end

    it 'warns when there is no LICENSE file' do
      release_dir.remove_file(basedir, 'LICENSE')

      expect(builder).to receive(:warn)
        .with(['Does not contain LICENSE within', release_dir].join(' '))
      builder.copy_files
    end

    it 'warns when there is no NOTICE file' do
      release_dir.remove_file(basedir, 'NOTICE')

      expect(builder).to receive(:warn)
        .with(['Does not contain NOTICE within', release_dir].join(' '))
      builder.copy_files
    end
  end

  describe 'the checksum' do
    let(:builder) { make_builder }

    before do
      release_dir.add_file(basedir, 'LICENSE')
      release_dir.add_file(basedir, 'NOTICE')
    end

    it 'exists when the builder has built' do
      builder.build
      expect(builder.checksum).to match(/[0-9a-f]+/)
    end

    it 'raises an exception if not yet built' do
      expect {
        builder.checksum
      }.to raise_error(RuntimeError,
        'cannot read checksum for not yet ' +
          'generated package/job/license')
    end
  end

  describe 'the fingerprint' do
    let(:builder) { make_builder }

    before do
      release_dir.add_file(basedir, 'LICENSE')
      release_dir.add_file(basedir, 'NOTICE')
    end

    it 'is stable' do
      expect {
        builder.reload
      }.to_not change { builder.fingerprint }
    end
  end

  describe 'generating a tarball' do
    let(:builder) { make_builder }

    before do
      release_dir.add_file(basedir, 'LICENSE', '1')
      release_dir.add_file(basedir, 'NOTICE', '1')
    end

    it 'includes the fingerprint in the archive filename' do
      builder.generate_tarball
      expect(File).to exist(File.join(release_dir, ".dev_builds/license/#{builder.fingerprint}.tgz"))
      expect(File).to exist(release_dir.join(".dev_builds/license/#{builder.fingerprint}.tgz"))
    end
  end

  describe 'building the license archive' do
    let(:builder) { make_builder }

    before do
      release_dir.add_file(basedir, 'LICENSE', '1')
      release_dir.add_file(basedir, 'NOTICE', '1')
    end

    it 'includes the fingerprint in the archive filename' do
      builder.build
      expect(File).to exist(release_dir.join(".dev_builds/license/#{builder.fingerprint}.tgz"))
    end

    it 'creates a new version when the LICENSE is updated' do
      builder.build
      v1_fingerprint = builder.fingerprint

      expect(File.exists?(release_dir + "/.dev_builds/license/#{v1_fingerprint}.tgz")).to eql(true)

      release_dir.add_file(basedir, 'LICENSE', '2')
      builder = make_builder()
      builder.build

      expect(builder.fingerprint).to_not eq(v1_fingerprint)
      expect(File.exists?(release_dir + "/.dev_builds/license/#{builder.fingerprint}.tgz")).to eql(true)
    end

    it 'creates a new version when the NOTICE is updated' do
      builder.build
      v1_fingerprint = builder.fingerprint

      expect(File.exists?(release_dir + "/.dev_builds/license/#{v1_fingerprint}.tgz")).to eql(true)

      release_dir.add_file(basedir, 'NOTICE', '2')
      builder = make_builder()
      builder.build

      expect(builder.fingerprint).to_not eq(v1_fingerprint)
      expect(File.exists?(release_dir + "/.dev_builds/license/#{builder.fingerprint}.tgz")).to eql(true)
    end

    context 'building dev and final versions' do
      let(:fingerprint) { 'fake-digest' }

      before do
        allow(Digest::SHA1).to receive(:hexdigest).and_return(fingerprint)
        release_dir.add_file(basedir, 'LICENSE', '1')
        release_dir.add_file(basedir, 'NOTICE', '1')
      end

      it 'successfully builds a dev version' do
        storage_dir = '.dev_builds/license'

        release_dir.add_version(fingerprint, storage_dir, 'payload',
          { 'version' => fingerprint })

        builder = make_builder
        builder.use_dev_version

        expect(builder.tarball_path).to eql(release_dir.join(storage_dir, "#{fingerprint}.tgz"))
      end

      it 'successfully builds a final version' do
        storage_dir = '.final_builds/license'

        release_dir.add_version(fingerprint, storage_dir, 'payload',
          { 'version' => fingerprint, 'blobstore_id' => '12321' })

        builder = make_builder(true)
        builder.use_final_version

        expect(builder.tarball_path).to eql(release_dir.join(storage_dir, "#{fingerprint}.tgz"))
      end
    end
  end
end
