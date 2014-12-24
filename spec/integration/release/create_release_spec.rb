require 'securerandom'
require 'spec_helper'

describe 'create release', type: :integration do
  include Bosh::Spec::CreateReleaseOutputParsers
  with_reset_sandbox_before_each

  it 'cannot create a final release without the blobstore configured', no_reset: true do
    Dir.chdir(ClientSandbox.test_release_dir) do
      FileUtils.rm_rf('dev_releases')

      FileUtils.cp(spec_asset('empty_blobstore_config.yml'), 'config/final.yml')

      out = bosh_runner.run_in_current_dir('create release --final', failure_expected: true)
      expect(out).to match(/Missing blobstore configuration, please update config\/final\.yml/)
    end
  end

  it 'cannot create a final release without the blobstore secret configured', no_reset: true do
    Dir.chdir(ClientSandbox.test_release_dir) do
      FileUtils.rm_rf('dev_releases')

      FileUtils.cp(spec_asset('blobstore_config_requiring_credentials.yml'), 'config/final.yml')

      out = bosh_runner.run_in_current_dir('create release --final', failure_expected: true)
      expect(out).to match(/Missing blobstore secret configuration, please update config\/private\.yml/)
    end
  end

  it 'allows creation of new final releases with the same content as the latest final release' do
    Dir.chdir(ClientSandbox.test_release_dir) do
      out = bosh_runner.run_in_current_dir('create release --final')
      expect(parse_release_version(out)).to eq('1')

      out = bosh_runner.run_in_current_dir('create release --final --force')
      expect(parse_release_version(out)).to eq('2')

      out = bosh_runner.run_in_current_dir('create release --final --force')
      expect(parse_release_version(out)).to eq('3')
    end
  end

  it 'allows creation of new dev releases with the same content as the latest dev release' do
    Dir.chdir(ClientSandbox.test_release_dir) do
      out = bosh_runner.run_in_current_dir('create release')
      expect(parse_release_version(out)).to eq('0+dev.1')

      out = bosh_runner.run_in_current_dir('create release --force')
      expect(parse_release_version(out)).to eq('0+dev.2')

      out = bosh_runner.run_in_current_dir('create release --force')
      expect(parse_release_version(out)).to eq('0+dev.3')
    end
  end

  it 'allows creation of new final releases with the same content as a previous final release' do
    Dir.chdir(ClientSandbox.test_release_dir) do
      out = bosh_runner.run_in_current_dir('create release --final')
      expect(parse_release_version(out)).to eq('1')

      with_changed_release do
        out = bosh_runner.run_in_current_dir('create release --final --force')
        expect(parse_release_version(out)).to eq('2')
      end

      out = bosh_runner.run_in_current_dir('create release --final --force')
      expect(parse_release_version(out)).to eq('3')
    end
  end

  it 'allows creation of new dev releases with the same content as a previous dev release' do
    Dir.chdir(ClientSandbox.test_release_dir) do
      out = bosh_runner.run_in_current_dir('create release')
      expect(parse_release_version(out)).to eq('0+dev.1')

      with_changed_release do
        out = bosh_runner.run_in_current_dir('create release --force')
        expect(parse_release_version(out)).to eq('0+dev.2')
      end

      out = bosh_runner.run_in_current_dir('create release --force')
      expect(parse_release_version(out)).to eq('0+dev.3')
    end
  end

  it 'allows creation of a final release without an existing dev release' do
    Dir.chdir(ClientSandbox.test_release_dir) do
      expect(File).to_not exist('releases/bosh-release/bosh-release-1.yml')

      out = bosh_runner.run_in_current_dir('create release --final')
      expect(out).to_not match(/Please consider creating a dev release first/)

      expect(Dir).to_not exist('dev_releases')
      expect(File).to exist('releases/bosh-release/bosh-release-1.yml')
    end
  end

  it 'allows creation of new final release without .gitignore files' do
    Dir.chdir(ClientSandbox.test_release_dir) do
      out = bosh_runner.run_in_current_dir('create release --final')
      expect(out).to match(/Release version: 1/)

      `git add .`
      `git commit -m 'final release 1'`
      `git clean -fdx`

      out = bosh_runner.run_in_current_dir('create release --final --force')
      expect(out).to match(/Release version: 2/)
    end
  end

  context 'when no previous releases have been made' do
    it 'final release uploads the job & package blobs' do
      Dir.chdir(ClientSandbox.test_release_dir) do
        expect(File).to_not exist('releases/bosh-release/bosh-release-1.yml')

        out = bosh_runner.run_in_current_dir('create release --final')
        expect(out).to match(/Uploaded, blobstore id/)
        expect(out).to_not match(/This package has already been uploaded/)
      end
    end

    it 'uses a provided --name' do
      Dir.chdir(ClientSandbox.test_release_dir) do
        out = bosh_runner.run_in_current_dir('create release --name "bosh-fork"')
        expect(parse_release_name(out)).to eq('bosh-fork')
        expect(parse_release_version(out)).to eq('0+dev.1')
      end
    end
  end

  context 'when previous release have been made' do
    it 'allows creation of a new dev release with a new name' do
      Dir.chdir(ClientSandbox.test_release_dir) do
        out = bosh_runner.run_in_current_dir('create release')
        expect(parse_release_name(out)).to eq('bosh-release')
        expect(parse_release_version(out)).to eq('0+dev.1')

        out = bosh_runner.run_in_current_dir('create release --name "bosh-fork"')
        expect(parse_release_name(out)).to eq('bosh-fork')
        expect(parse_release_version(out)).to eq('0+dev.1')
      end
    end

    it 'allows creation of a new final release with a new name' do
      Dir.chdir(ClientSandbox.test_release_dir) do
        out = bosh_runner.run_in_current_dir('create release --final')
        expect(parse_release_name(out)).to eq('bosh-release')
        expect(parse_release_version(out)).to eq('1')

        `git add config/final.yml`
        `git add .final_builds`
        `git add releases`
        `git commit -m 'final release 1'`

        out = bosh_runner.run_in_current_dir('create release --final --name "bosh-fork"')
        expect(parse_release_name(out)).to eq('bosh-fork')
        expect(parse_release_version(out)).to eq('1')
      end
    end

    it 'allows creation of a new final release with a custom name & version' do
      Dir.chdir(ClientSandbox.test_release_dir) do
        out = bosh_runner.run_in_current_dir('create release --final --name fake-release --version 2.0.1')
        expect(parse_release_name(out)).to eq('fake-release')
        expect(parse_release_version(out)).to eq('2.0.1')
      end
    end
  end

  it 'creates a new final release with a default version' do
    Dir.chdir(ClientSandbox.test_release_dir) do
      File.open('config/final.yml', 'w') do |final|
        final.puts YAML.dump(
          'blobstore' => {
            'provider' => 'local',
            'options' => { 'blobstore_path' => current_sandbox.blobstore_storage_dir },
          },

        )
      end
      File.open('config/private.yml', 'w') do |final|
        final.puts YAML.dump(
          'blobstore_secret' => 'something',
          'blobstore' => {
            'local' => {},
          },
        )
      end

      bosh_runner.run_in_current_dir('create release --force')

      out = bosh_runner.run_in_current_dir('create release --final --force')
      expect(parse_release_version(out)).to eq('1')
      manifest_1 = parse_release_manifest_path(out)
      expect(manifest_1).to eq(
        File.join(Dir.pwd, 'releases', 'bosh-release', 'bosh-release-1.yml')
      )
      expect(File).to exist(manifest_1)

      # modify a release file to force a new version
      `echo ' ' >> #{File.join(ClientSandbox.test_release_dir, 'jobs', 'foobar', 'templates', 'foobar_ctl')}`
      bosh_runner.run_in_current_dir('create release --force')

      out = bosh_runner.run_in_current_dir('create release --final --force')
      expect(parse_release_version(out)).to eq('2')
      manifest_1 = parse_release_manifest_path(out)
      expect(manifest_1).to eq(
        File.join(Dir.pwd, 'releases', 'bosh-release', 'bosh-release-2.yml')
      )
      expect(File).to exist(manifest_1)
    end
  end

  it 'release tarball does not include excluded files' do
    Dir.chdir(ClientSandbox.test_release_dir) do
      FileUtils.rm_rf('dev_releases')

      out = bosh_runner.run_in_current_dir('create release --with-tarball')
      release_tarball = parse_release_tarball_path(out)

      Dir.mktmpdir do |temp_dir|
        `tar xzf #{release_tarball} -C #{temp_dir}`
        foo_package = File.join(temp_dir, 'packages', 'foo.tgz')
        release_file_list = `tar -tzf #{foo_package}`
        expect(release_file_list).to_not include('excluded_file')
        expect(release_file_list).to include('foo')
      end
    end
  end

  def with_changed_release
    new_file = File.join('src', 'bar', SecureRandom.uuid)
    begin
      FileUtils.touch(new_file)
      yield
    ensure
      FileUtils.rm_rf(new_file)
    end
  end
end
