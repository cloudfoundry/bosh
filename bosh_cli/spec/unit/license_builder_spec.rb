require 'spec_helper'

describe Bosh::Cli::LicenseBuilder, 'dev build' do
  before do
    spec_package.add_dir('blobs')
    spec_package.add_dir('src')
    spec_package.add_dir('src_alt')
  end

  def make_builder(final = false)
    blobstore = double('blobstore')
    Bosh::Cli::LicenseBuilder.new(spec_package, final, blobstore)
  end

  it 'whines when there is no license file named LICENSE/NOTICE in the release root repo' do
    builder = make_builder()
    spec_package.add_file('license', 'LICENSE1')

    builder.copy_files
    expect(builder.copy_files).to eql(0)
  end


  it 'has no way to calculate checksum for not yet generated license' do
    expect {
      builder = make_builder()
      spec_package.add_file('license', 'LICENSE')
      builder.checksum
    }.to raise_error(RuntimeError,
                         'cannot read checksum for not yet ' +
                           'generated package/job/license')
  end

  it 'has a checksum for a generated license' do
    builder = make_builder()
    spec_package.add_file(nil, 'LICENSE', '1')
    spec_package.add_file(nil, 'NOTICE', '2')
    builder.build
    expect(builder.checksum).to match(/[0-9a-f]+/)
  end

  it 'has stable fingerprint' do
    spec_package.add_file(nil, 'LICENSE')
    spec_package.add_file(nil, 'NOTICE')
    builder = make_builder()
    s1 = builder.fingerprint

    expect(builder.reload.fingerprint).to eql(s1)
  end

  it 'copies files to build directory' do
    spec_package.add_file(nil, 'LICENSE')
    spec_package.add_file(nil, 'NOTICE')

    builder = make_builder()
    expect(builder.copy_files).to eql(2)
  end

  it 'generates tarball' do
    spec_package.add_file(nil, 'LICENSE')
    spec_package.add_file(nil, 'NOTICE')
    builder = make_builder()
    expect(builder.generate_tarball).to eql(true)
  end

  it 'can point to either dev or a final version of a package' do
    fingerprint = 'fake-fingerprint'
    allow(Digest::SHA1).to receive(:hexdigest).and_return(fingerprint)

    spec_package.add_file(nil, 'LICENSE')
    spec_package.add_file(nil, 'NOTICE')

    license_name = 'LICENSE'
    final_storage_dir = File.join(spec_package, '.final_builds', 'license', license_name)
    final_versions = Bosh::Cli::Versions::VersionsIndex.new(final_storage_dir)
    final_storage = Bosh::Cli::Versions::LocalVersionStorage.new(final_storage_dir)

    dev_storage_dir = File.join(spec_package, '.dev_builds', 'license', license_name)
    dev_versions   = Bosh::Cli::Versions::VersionsIndex.new(dev_storage_dir)
    dev_storage = Bosh::Cli::Versions::LocalVersionStorage.new(dev_storage_dir)

    spec_package.add_version(final_versions, final_storage,
      fingerprint,
      { 'version' => fingerprint, 'blobstore_id' => '12321' },
      get_tmp_file_path('payload'))

    spec_package.add_version(dev_versions, dev_storage,
      fingerprint,
      { 'version' => fingerprint },
      get_tmp_file_path('dev_payload'))

    builder = make_builder()
    builder.use_dev_version || builder.generate_tarball

    expect(builder.tarball_path).to eql(File.join(
      spec_package, '.dev_builds', 'license', "#{fingerprint}.tgz"))


    builder = make_builder(true)
    builder.use_final_version || builder.generate_tarball
    expect(builder.tarball_path).to eql(File.join(
      spec_package, '.final_builds', 'license', "#{fingerprint}.tgz"))

 end

  it 'creates a new version tarball' do
    spec_package.add_file(nil,'LICENSE', '1')
    spec_package.add_file(nil,'NOTICE', '1')
    builder = make_builder()

    v1_fingerprint = builder.fingerprint
    expect(File.exists?(spec_package + "/.dev_builds/license/#{v1_fingerprint}.tgz")).to eql(false)

    builder.build
    expect(File.exists?(spec_package + "/.dev_builds/license/#{v1_fingerprint}.tgz")).to eql(true)

    builder = make_builder()
    builder.build

    expect(File.exists?(spec_package + "/.dev_builds/license/#{v1_fingerprint}.tgz")).to eql(true)
    expect(File.exists?(spec_package + '/.dev_builds/license/other-fingerprint.tgz')).to eql(false)

    spec_package.add_file(nil, 'LICENSE', '2')
    spec_package.add_file(nil, 'NOTICE', '2')
    builder = make_builder()
    builder.build

    v2_fingerprint = builder.fingerprint

    expect(File.exists?(spec_package + "/.dev_builds/license/#{v1_fingerprint}.tgz")).to eql(true)
    expect(File.exists?(spec_package + "/.dev_builds/license/#{v2_fingerprint}.tgz")).to eql(true)

  end

end
