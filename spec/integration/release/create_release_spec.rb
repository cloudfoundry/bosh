require 'securerandom'
require 'spec_helper'

describe 'create release', type: :integration do
  include Bosh::Spec::CreateReleaseOutputParsers
  with_reset_sandbox_before_each
  SHA1_REGEXP = /^[0-9a-f]{40}$/

  describe 'release creation' do
    before do
      Dir.chdir(ClientSandbox.test_release_dir) do
        bosh_runner.run_in_current_dir('create release --final --with-tarball')
      end
    end

    it 'updates the .final_builds index for each job and package' do
      Dir.chdir(ClientSandbox.test_release_dir) do
        ['a', 'b', 'bar', 'blocking_package', 'c', 'errand1', 'fails_with_too_much_output', 'foo'].each do |package_name|
          index = YAML.load_file(".final_builds/packages/#{package_name}/index.yml")
          fingerprint = index['builds'].keys.first
          expect(index).to match(
              'builds' => {
                fingerprint => {
                  'version' => fingerprint,
                  'sha1' => SHA1_REGEXP,
                  'blobstore_id' => kind_of(String),
                }
              },
              'format-version' => '2'
            )

          blob_file = File.join(ClientSandbox.blobstore_dir, index['builds'][fingerprint]['blobstore_id'])
          expect(File.exist?(blob_file)).to eq(true)
          expect(Digest::SHA1.file(blob_file)).to eq(index['builds'][fingerprint]['sha1'])
        end

        ['errand1', 'errand_without_package', 'fails_with_too_much_output', 'foobar', 'job_with_blocking_compilation', 'transitive_deps',].each do |job_name|
          index = YAML.load_file(".final_builds/jobs/#{job_name}/index.yml")
          fingerprint = index['builds'].keys.first
          expect(index).to match(
              'builds' => {
                fingerprint => {
                  'version' => fingerprint,
                  'sha1' => SHA1_REGEXP,
                  'blobstore_id' => kind_of(String),
                }
              },
              'format-version' => '2'
            )

          tarblob = File.join(ClientSandbox.blobstore_dir, index['builds'][fingerprint]['blobstore_id'])
          expect(File.exist?(tarblob)).to eq(true)
          expect(Digest::SHA1.file(tarblob)).to eq(index['builds'][fingerprint]['sha1'])
        end
      end
    end

    it 'creates a release manifest' do
      Dir.chdir(ClientSandbox.test_release_dir) do
        expect(YAML.load_file('releases/bosh-release/bosh-release-1.yml')).to match(
            'packages' => [
              package_desc('a', ['b']),
              package_desc('b', ['c']),
              package_desc('bar', ['foo']),
              package_desc('blocking_package', []),
              package_desc('c', []),
              package_desc('errand1', []),
              package_desc('fails_with_too_much_output', []),
              package_desc('foo', []),
            ],
            'jobs' => [
              job_desc('errand1'),
              job_desc('errand_without_package'),
              job_desc('fails_with_too_much_output'),
              job_desc('foobar'),
              job_desc('job_with_blocking_compilation'),
              job_desc('transitive_deps'),
            ],

            'commit_hash' => /[0-9a-f]{8}/,
            'uncommitted_changes' => true,
            'name' => 'bosh-release',
            'version' => '1',
          )
      end
    end

    it 'updates the index' do
      Dir.chdir(ClientSandbox.test_release_dir) do
        index = YAML.load_file('releases/bosh-release/index.yml')
        builds = index['builds']
        uuid, _ = builds.first
        expect(index).to eq(
            'builds' => {
              uuid => {'version' => '1'}
            },
            'format-version' => '2',
          )
      end
    end

    it 'stashes stuff in a tarball' do
      Dir.chdir(ClientSandbox.test_release_dir) do
        files = `tar tzf releases/bosh-release/bosh-release-1.tgz`.chomp.split(/\n/)
        expect(files.reject {|f| f =~ /\/$/ }).to contain_exactly(
            './jobs/errand1.tgz',
            './jobs/errand_without_package.tgz',
            './jobs/fails_with_too_much_output.tgz',
            './jobs/foobar.tgz',
            './jobs/job_with_blocking_compilation.tgz', 
            './jobs/transitive_deps.tgz',
            './packages/a.tgz',
            './packages/b.tgz',
            './packages/bar.tgz',
            './packages/blocking_package.tgz',
            './packages/c.tgz', 
            './packages/errand1.tgz',
            './packages/fails_with_too_much_output.tgz',
            './packages/foo.tgz',
            './release.MF'
          )
      end
    end
  end

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

  def package_desc(name, dependencies)
    sha = SHA1_REGEXP
    {'name' => name, 'version' => sha, 'fingerprint' => sha, 'dependencies' => dependencies, 'sha1' => sha, }
  end

  def job_desc(name)
    sha = SHA1_REGEXP
    {'name' => name, 'version' => sha, 'fingerprint' => sha, 'sha1' => sha, }
  end
end
