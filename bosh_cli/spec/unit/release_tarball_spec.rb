# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe Bosh::Cli::ReleaseTarball do
  let(:release_tarball) { Bosh::Cli::ReleaseTarball.new(tarball_path) }
  let(:tarball_path) { spec_asset('valid_release.tgz') }

  describe "verifying a release" do
    it "verifies and reports a valid release" do
      expect(release_tarball).to be_valid
    end

    it "verifies repacked release if appropriate option is set" do
      package_matches = ["86bd8b15562cde007f030a303fa64779af5fa4e7"]
      repacked_tarball_path = release_tarball.repack(package_matches)

      expect(release_tarball.skipped).to eq(1)

      repacked_tarball = Bosh::Cli::ReleaseTarball.new(repacked_tarball_path)
      expect(repacked_tarball.valid?).to be(false)
      repacked_tarball.reset_validation
      expect(repacked_tarball.valid?(:allow_sparse => true)).to be(true)
    end
  end

  describe 'convert_to_old_format' do
    let(:tarball_path) { spec_asset('valid_release_dev_version.tgz') }
    let(:unpack_dir) { Dir.mktmpdir }
    after { FileUtils.rm_rf(unpack_dir) }

    it 'converts dev version to old format in release tarball' do
      converted_tarball_path = release_tarball.convert_to_old_format

      `tar -C #{unpack_dir} -xzf #{converted_tarball_path} 2>&1`
      manifest_file = File.join(unpack_dir, 'release.MF')
      manifest = YAML.load(File.read(manifest_file))
      expect(manifest['version']).to eq('8.1.3-dev')
    end
  end
end
