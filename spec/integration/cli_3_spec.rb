require 'spec_helper'

describe 'Bosh::Spec::IntegrationTest::CliUsage 3' do
  include IntegrationExampleGroup
  # ~33s
  it 'uploads the latest generated release if no release path given' do
    Dir.chdir(TEST_RELEASE_DIR) do
      FileUtils.rm_rf('dev_releases')

      run_bosh('create release', Dir.pwd)
      run_bosh("target http://localhost:#{current_sandbox.director_port}")
      run_bosh('login admin admin')
      run_bosh('upload release', Dir.pwd)
    end

    out = run_bosh('releases')
    out.should =~ /bosh-release.+0\.1\-dev/
  end

  # ~41s
  it 'sparsely uploads the release' do
    release_1 = File.join(TEST_RELEASE_DIR, 'dev_releases/bosh-release-0.1-dev.tgz')
    release_2 = File.join(TEST_RELEASE_DIR, 'dev_releases/bosh-release-0.2-dev.tgz')

    Dir.chdir(TEST_RELEASE_DIR) do
      FileUtils.rm_rf('dev_releases')

      run_bosh('create release --with-tarball', Dir.pwd)
      File.exists?(release_1).should be_true
    end

    run_bosh("target http://localhost:#{current_sandbox.director_port}")
    run_bosh('login admin admin')
    run_bosh("upload release #{release_1}")

    Dir.chdir(TEST_RELEASE_DIR) do
      new_file = File.join('src', 'bar', 'bla')
      begin
        FileUtils.touch(new_file)

        run_bosh('create release --force --with-tarball', Dir.pwd)
        File.exists?(release_2).should be_true
      ensure
        FileUtils.rm_rf(new_file)
      end
    end

    out = run_bosh("upload release #{release_2}")
    out.should =~ regexp("foo (0.1-dev)                 SKIP\n")
    # No job skipping for the moment (because of rebase),
    # will be added back once job matching is implemented
    out.should =~ regexp("foobar (0.1-dev)              UPLOAD\n")
    out.should =~ regexp("bar (0.2-dev)                 UPLOAD\n")
    out.should =~ regexp('Checking if can repack release for faster upload')
    out.should =~ regexp('Release repacked')
    out.should =~ /Release uploaded/

    out = run_bosh('releases')
    out.should =~ /releases total: 1/i
    out.should =~ /bosh-release.+0\.1\-dev.*0\.2\-dev/m
  end

  # ~57s
  it 'release lifecycle: create, upload, update (w/sparse upload), delete' do
    release_1 = File.join(TEST_RELEASE_DIR, 'dev_releases/bosh-release-0.1-dev.yml')
    release_2 = File.join(TEST_RELEASE_DIR, 'dev_releases/bosh-release-0.2-dev.yml')
    commit_hash = ''

    Dir.chdir(TEST_RELEASE_DIR) do
      commit_hash = `git show-ref --head --hash=8 2> /dev/null`.split.first

      run_bosh('create release', Dir.pwd)
      File.exists?(release_1).should be_true

      run_bosh("target http://localhost:#{current_sandbox.director_port}")
      run_bosh('login admin admin')
      run_bosh("upload release #{release_1}", Dir.pwd)

      new_file = File.join('src', 'bar', 'bla')
      begin
        FileUtils.touch(new_file)
        # In an ephemeral git repo
        `git add .`
        `git commit -m 'second dev release'`
        run_bosh('create release', Dir.pwd)
        File.exists?(release_2).should be_true
      ensure
        FileUtils.rm_rf(new_file)
      end

      out = run_bosh("upload release #{release_2}", Dir.pwd)
      out.should =~ regexp('Building tarball')
      out.should_not =~ regexp('Checking if can repack')
      out.should_not =~ regexp('Release repacked')
      out.should =~ /Release uploaded/
    end

    out = run_bosh('releases')
    out.should =~ /releases total: 1/i
    out.should =~ /bosh-release.+0\.1\-dev.*0\.2\-dev/m

    run_bosh('delete release bosh-release 0.2-dev')
    expect_output('releases', <<-OUT)
    +--------------+----------+-------------+
    | Name         | Versions | Commit Hash |
    +--------------+----------+-------------+
    | bosh-release | 0.1-dev  | #{commit_hash}    |
    +--------------+----------+-------------+

    Releases total: 1
    OUT

    run_bosh('delete release bosh-release 0.1-dev')
    expect_output('releases', <<-OUT )
    No releases
    OUT
  end

  # ~9s
  it 'cannot upload malformed release', no_reset: true do
    release_filename = spec_asset('release_invalid_checksum.tgz')

    run_bosh("target http://localhost:#{current_sandbox.director_port}")
    run_bosh('login admin admin')
    out = run_bosh("upload release #{release_filename}", nil, failure_expected: true)

    out.should =~ /Release is invalid, please fix, verify and upload again/
  end

  # ~25s
  it 'allows deleting a whole release' do
    release_filename = spec_asset('valid_release.tgz')

    run_bosh("target http://localhost:#{current_sandbox.director_port}")
    run_bosh('login admin admin')
    run_bosh("upload release #{release_filename}")

    out = run_bosh('delete release appcloud')
    out.should =~ regexp('Deleted `appcloud')

    expect_output('releases', <<-OUT)
    No releases
    OUT
  end

  # ~22s
  it 'allows deleting a particular release version' do
    release_filename = spec_asset('valid_release.tgz')

    run_bosh("target http://localhost:#{current_sandbox.director_port}")
    run_bosh('login admin admin')
    run_bosh("upload release #{release_filename}")

    out = run_bosh('delete release appcloud 0.1')
    out.should =~ regexp('Deleted `appcloud/0.1')
  end
end
