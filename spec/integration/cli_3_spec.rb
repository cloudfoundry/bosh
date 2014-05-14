require 'spec_helper'

describe 'cli: 3', type: :integration do
  with_reset_sandbox_before_each

  # ~33s
  it 'uploads the latest generated release if no release path given' do
    Dir.chdir(TEST_RELEASE_DIR) do
      FileUtils.rm_rf('dev_releases')

      bosh_runner.run_in_current_dir('create release')
      target_and_login
      bosh_runner.run_in_current_dir('upload release')
    end

    out = bosh_runner.run('releases')
    expect(out).to match /bosh-release.+0\.1\-dev/
  end

  # ~41s
  it 'sparsely uploads the release' do
    release_1 = File.join(TEST_RELEASE_DIR, 'dev_releases/bosh-release-0.1-dev.tgz')
    release_2 = File.join(TEST_RELEASE_DIR, 'dev_releases/bosh-release-0.2-dev.tgz')

    Dir.chdir(TEST_RELEASE_DIR) do
      FileUtils.rm_rf('dev_releases')

      bosh_runner.run_in_current_dir('create release --with-tarball')
      expect(File.exists?(release_1)).to be(true)
    end

    target_and_login
    bosh_runner.run("upload release #{release_1}")

    Dir.chdir(TEST_RELEASE_DIR) do
      new_file = File.join('src', 'bar', 'bla')
      begin
        FileUtils.touch(new_file)

        bosh_runner.run_in_current_dir('create release --force --with-tarball')
        expect(File.exists?(release_2)).to be(true)
      ensure
        FileUtils.rm_rf(new_file)
      end
    end

    out = bosh_runner.run("upload release #{release_2}")
    expect(out).to match /foo\s*\(.*\)\s*SKIP/
    # No job skipping for the moment (because of rebase),
    # will be added back once job matching is implemented
    expect(out).to match /foobar\s*\(.*\)\s*UPLOAD/
    expect(out).to match /bar\s*\(.*\)\s*UPLOAD/
    expect(out).to match regexp('Checking if can repack release for faster upload')
    expect(out).to match regexp('Release repacked')
    expect(out).to match /Release uploaded/

    out = bosh_runner.run('releases')
    expect(out).to match /releases total: 1/i
    expect(out).to match /bosh-release.+0\.1\-dev.*0\.2\-dev/m
  end

  # ~57s
  it 'release lifecycle: create, upload, update (w/sparse upload), delete' do
    release_1 = File.join(TEST_RELEASE_DIR, 'dev_releases/bosh-release-0.1-dev.yml')
    release_2 = File.join(TEST_RELEASE_DIR, 'dev_releases/bosh-release-0.2-dev.yml')
    commit_hash = ''

    Dir.chdir(TEST_RELEASE_DIR) do
      commit_hash = `git show-ref --head --hash=8 2> /dev/null`.split.first

      bosh_runner.run_in_current_dir('create release')
      expect(File.exists?(release_1)).to be(true)

      target_and_login
      bosh_runner.run_in_current_dir("upload release #{release_1}")

      new_file = File.join('src', 'bar', 'bla')
      begin
        FileUtils.touch(new_file)
        # In an ephemeral git repo
        `git add .`
        `git commit -m 'second dev release'`
        bosh_runner.run_in_current_dir('create release')
        expect(File.exists?(release_2)).to be(true)
      ensure
        FileUtils.rm_rf(new_file)
      end

      out = bosh_runner.run_in_current_dir("upload release #{release_2}")
      expect(out).to match regexp('Building tarball')
      expect(out).not_to match regexp('Checking if can repack')
      expect(out).not_to match regexp('Release repacked')
      expect(out).to match /Release uploaded/
    end

    out = bosh_runner.run('releases')
    expect(out).to match /releases total: 1/i
    expect(out).to match /bosh-release.+0\.1\-dev.*0\.2\-dev/m

    bosh_runner.run('delete release bosh-release 0.2-dev')
    expect_output('releases', <<-OUT)
    +--------------+----------+-------------+
    | Name         | Versions | Commit Hash |
    +--------------+----------+-------------+
    | bosh-release | 0.1-dev  | #{commit_hash}    |
    +--------------+----------+-------------+

    Releases total: 1
    OUT

    bosh_runner.run('delete release bosh-release 0.1-dev')
    expect_output('releases', <<-OUT )
    No releases
    OUT
  end

  # ~9s
  it 'cannot upload malformed release', no_reset: true do
    target_and_login

    release_filename = spec_asset('release_invalid_checksum.tgz')
    out = bosh_runner.run("upload release #{release_filename}", failure_expected: true)
    expect(out).to match /Release is invalid, please fix, verify and upload again/
  end

  # ~25s
  it 'allows deleting a whole release' do
    target_and_login

    release_filename = spec_asset('valid_release.tgz')
    bosh_runner.run("upload release #{release_filename}")

    out = bosh_runner.run('delete release appcloud')
    expect(out).to match regexp('Deleted `appcloud')

    expect_output('releases', <<-OUT)
    No releases
    OUT
  end

  # ~22s
  it 'allows deleting a particular release version' do
    target_and_login

    release_filename = spec_asset('valid_release.tgz')
    bosh_runner.run("upload release #{release_filename}")

    out = bosh_runner.run('delete release appcloud 0.1')
    expect(out).to match regexp('Deleted `appcloud/0.1')
  end
end
