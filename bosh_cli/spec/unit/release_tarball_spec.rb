
# Copyright (c) 2009-2012 VMware, Inc.
require "spec_helper"

describe Bosh::Cli::ReleaseTarball do
  let(:release_tarball) { Bosh::Cli::ReleaseTarball.new(tarball_path) }
  let(:tarball_path) { spec_asset('test_release.tgz') }

  describe "verifying a release" do
    it "verifies and reports a valid release" do
      expect(release_tarball).to be_valid
    end

    it "verifies repacked release if appropriate option is set" do
      package_matches = ["93fade7dd8950d8a1dd2bf5ec751e478af3150e9"]
      repacked_tarball_path = release_tarball.repack(package_matches)

      expect(release_tarball.skipped).to eq(1)

      repacked_tarball = Bosh::Cli::ReleaseTarball.new(repacked_tarball_path)
      expect(repacked_tarball.valid?).to be(false)
      repacked_tarball.reset_validation
      expect(repacked_tarball.valid?(:allow_sparse => true)).to be(true)
    end
  end

  describe 'release file path contains spaces' do
    let(:tarball_path) { spec_asset('test_release  _dev_version.tgz') }
    let(:unpack_dir) { Dir.mktmpdir }
    before { FileUtils.copy spec_asset('test_release.tgz'), tarball_path }
    after { FileUtils.rm_rf(unpack_dir); FileUtils.rm_rf(tarball_path) }

    it 'correctly unpacks' do
      result = release_tarball.unpack
      expect(result).to be true
    end
  end

  describe 'convert_to_old_format' do
    let(:tarball_path) { spec_asset('test_release-dev_version.tgz') }
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

  describe 'replace_manifest' do
    it 'overwrites working copy of release.MF' do
      release_tarball.replace_manifest("foo" => "bar")
      expect(release_tarball.manifest).to match <<-EOF
---
foo: bar
      EOF
    end
  end

  describe 'create_from_unpacked' do
    it 'generates identical tarball when repacking with no changes' do
      tarball_path = spec_asset('release_no_version.tgz')
      release_tarball = Bosh::Cli::ReleaseTarball.new(tarball_path)
      release_tarball.unpack
      new_tar_path = File.join(Dir.mktmpdir, "newly-packed.tgz")
      release_tarball.create_from_unpacked(new_tar_path)

      expect(new_tar_path).to have_same_tarball_contents tarball_path
    end

    it 'can create a tarball with a space in the file name' do
      tarball_path = spec_asset('release_no_version.tgz')
      release_tarball = Bosh::Cli::ReleaseTarball.new(tarball_path)
      release_tarball.unpack
      new_tar_path = File.join(Dir.mktmpdir, "newly-  packed.tgz")

      release_tarball.create_from_unpacked(new_tar_path)

      expect(new_tar_path).to have_same_tarball_contents tarball_path
    end

    it 'creates a tarball that reflects changes made in @unpack_dir' do
      manifest = Psych.load(release_tarball.manifest)
      manifest["extra_stuff"] = "it's here!"
      release_tarball.replace_manifest(manifest)

      new_tar_path = File.join(Dir.mktmpdir, "newly-packed.tgz")
      release_tarball.create_from_unpacked(new_tar_path)
      expect(File.exist?(new_tar_path)).to be(true)

      new_tarball = Bosh::Cli::ReleaseTarball.new(new_tar_path)
      expect(new_tarball).to be_valid, "Tarball is not valid, errors: #{new_tarball.errors}"
      expect(new_tarball.manifest).to match release_tarball.manifest
    end
  end

  describe 'upload a release' do
    it 'can untar manifest only if uploading the same release a 2nd time' do
      tarball_path = spec_asset('test_release.tgz')
      release_tarball = Bosh::Cli::ReleaseTarball.new(tarball_path)
      expect(release_tarball).to_not receive(:unpack)
      expect(release_tarball).to_not receive(:validate)

      release_tarball.validate_manifest
      expect(release_tarball).to be_valid
    end
  end

  describe 'unpacking using tar' do
    let(:bsd_tar_version) { 'bsdtar 2.8.3 - libarchive 2.8.3' }
    let(:gnu_tar_version) do
        <<-version
          tar (GNU tar) 1.27.1
          Copyright (C) 2013 Free Software Foundation, Inc.
          License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>.
          This is free software: you are free to change and redistribute it.
          There is NO WARRANTY, to the extent permitted by law.
        version
    end

    let(:unrecognized_tar_version) { 'unrecognized tar' }

    before do
      @tmpDir = Dir.mktmpdir
      allow(Kernel).to receive(:system).and_return(true)
      allow(Dir).to receive(:mktmpdir).and_return(@tmpDir)
      allow_any_instance_of(Bosh::Cli::ReleaseTarball).to receive(:load_yaml_file).and_return({})
    end

    context 'when unpacking single file' do
      it 'calls correct bsd tar command' do
        tarball_path = spec_asset('test_release.tgz')

        allow(Open3).to receive(:capture3).and_return(bsd_tar_version)
        release_tarball = Bosh::Cli::ReleaseTarball.new(tarball_path)

        expect(Kernel).to have_received(:system).with("tar", "-C", anything, "--fast-read", "-xzf", tarball_path, "./release.MF", anything)
      end

      it 'calls correct GNU tar command' do
        tarball_path = spec_asset('test_release.tgz')

        allow(Open3).to receive(:capture3).and_return(gnu_tar_version)
        release_tarball = Bosh::Cli::ReleaseTarball.new(tarball_path)

        expect(Kernel).to have_received(:system).with("tar", "-C", anything,"-xzf", tarball_path,"--occurrence", "./release.MF", anything)
      end

      it 'calls correct command for unrecognized tar' do
        tarball_path = spec_asset('test_release.tgz')

        allow(Open3).to receive(:capture3).and_return(unrecognized_tar_version)
        release_tarball = Bosh::Cli::ReleaseTarball.new(tarball_path)

        expect(Kernel).to have_received(:system).with("tar", "-C", anything,"-xzf", tarball_path, "./release.MF", anything)
      end
    end

    context 'when unpacking whole directory' do
      it 'calls correct bsd tar command' do
        tarball_path = spec_asset('test_release.tgz')

        allow(Open3).to receive(:capture3).and_return(bsd_tar_version)
        release_tarball = Bosh::Cli::ReleaseTarball.new(tarball_path)

        release_tarball.unpack_jobs

        expect(Kernel).to have_received(:system).with("tar", "-C", anything, "-xzf", tarball_path, "./jobs/", anything)
      end

      it 'calls correct GNU tar command' do
        tarball_path = spec_asset('test_release.tgz')

        allow(Open3).to receive(:capture3).and_return(gnu_tar_version)
        release_tarball = Bosh::Cli::ReleaseTarball.new(tarball_path)

        release_tarball.unpack_jobs

        expect(Kernel).to have_received(:system).with("tar", "-C", anything, "-xzf", tarball_path, "--occurrence", "./jobs/", anything)
      end

      it 'calls correct command for unrecognized tar' do
        tarball_path = spec_asset('test_release.tgz')

        allow(Open3).to receive(:capture3).and_return(unrecognized_tar_version)
        release_tarball = Bosh::Cli::ReleaseTarball.new(tarball_path)

        release_tarball.unpack_jobs

        expect(Kernel).to have_received(:system).with("tar", "-C", anything, "-xzf", tarball_path, "./jobs/", anything)
      end

    end
    context 'when unpacking a file fails' do
      it 'removes dot slash prefix and tries again' do
        tarball_path = spec_asset('test_release.tgz')

        allow(Kernel).to receive(:system).with("tar", "-C", anything, "-xzf", tarball_path, "--occurrence", "./jobs/", anything).and_return(false)

        allow(Open3).to receive(:capture3).and_return(gnu_tar_version)
        release_tarball = Bosh::Cli::ReleaseTarball.new(tarball_path)

        release_tarball.unpack_jobs

        expect(Kernel).to have_received(:system).with("tar", "-C", anything, "-xzf", tarball_path,  "--occurrence", "jobs/", anything)
      end

      it 'adds dot slash prefix and tries again' do
        tarball_path = spec_asset('test_release.tgz')

        allow(Kernel).to receive(:system).with("tar", "-C", anything, "-xzf", tarball_path, "--occurrence", "jobs/", anything).and_return(false)

        allow(Open3).to receive(:capture3).and_return(gnu_tar_version)
        release_tarball = Bosh::Cli::ReleaseTarball.new(tarball_path)

        release_tarball.unpack_jobs

        expect(Kernel).to have_received(:system).with("tar", "-C", anything, "-xzf", tarball_path,  "--occurrence", "./jobs/", anything)
      end
    end
  end
end
