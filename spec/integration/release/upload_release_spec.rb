require 'spec_helper'

describe 'upload release', type: :integration do
  include Bosh::Spec::CreateReleaseOutputParsers
  with_reset_sandbox_before_each

  # ~31s
  it 'can upload a release' do
    release_filename = spec_asset('valid_release.tgz')

    target_and_login
    out = bosh_runner.run("upload release #{release_filename}")

    expect(out).to match /release uploaded/i

    out = bosh_runner.run('releases')
    expect(out).to match /releases total: 1/i
    expect(out).to match /appcloud.+0\.1/
  end

  # ~33s
  it 'uploads the latest generated release if no release path given' do
    Dir.chdir(TEST_RELEASE_DIR) do
      FileUtils.rm_rf('dev_releases')

      bosh_runner.run_in_current_dir('create release')
      target_and_login
      bosh_runner.run_in_current_dir('upload release')
    end

    out = bosh_runner.run('releases')
    expect(out).to match /bosh-release.+0\+dev\.1/
  end

  # ~41s
  it 'sparsely uploads the release' do
    Dir.chdir(TEST_RELEASE_DIR) do
      FileUtils.rm_rf('dev_releases')

      out = bosh_runner.run_in_current_dir('create release --with-tarball')
      release_tarball_1 = parse_release_tarball_path(out)
      expect(File).to exist(release_tarball_1)

      target_and_login
      bosh_runner.run("upload release #{release_tarball_1}")

      new_file = File.join('src', 'bar', 'bla')
      begin
        FileUtils.touch(new_file)

        out = bosh_runner.run_in_current_dir('create release --force --with-tarball')
        release_tarball_2 = parse_release_tarball_path(out)
        expect(File).to exist(release_tarball_2)
      ensure
        FileUtils.rm_rf(new_file)
      end

      out = bosh_runner.run("upload release #{release_tarball_2}")
      expect(out).to match /Checking if can repack release for faster upload/
      expect(out).to match /foo\s*\(.*\)\s*SKIP/
      expect(out).to match /foobar\s*\(.*\)\s*UPLOAD/
      expect(out).to match /bar\s*\(.*\)\s*UPLOAD/
      expect(out).to match /Release repacked/
      expect(out).to match /Started creating new packages > bar.*Done/
      expect(out).to match /Started processing 7 existing packages > Processing 7 existing packages.*Done/
      expect(out).to match /Started processing 5 existing jobs > Processing 5 existing jobs.*Done/
      expect(out).to match /Release uploaded/

      out = bosh_runner.run('releases')
      expect(out).to match /releases total: 1/i
      expect(out).to match /bosh-release.+0\+dev\.1.*0\+dev\.2/m
    end
  end

  # ~9s
  it 'cannot upload malformed release', no_reset: true do
    target_and_login

    release_filename = spec_asset('release_invalid_checksum.tgz')
    out = bosh_runner.run("upload release #{release_filename}", failure_expected: true)
    expect(out).to match /Release is invalid, please fix, verify and upload again/
  end

  it 'fails to upload a release that is already uploaded' do
    release_filename = spec_asset('valid_release.tgz')

    target_and_login
    bosh_runner.run("upload release #{release_filename}")
    out = bosh_runner.run("upload release #{release_filename}", failure_expected: true)

    expect(out).to match 'This release version has already been uploaded'
  end

  # ~32s
  it 'marks releases that have uncommitted changes' do
    commit_hash = ''

    Dir.chdir(TEST_RELEASE_DIR) do
      commit_hash = `git show-ref --head --hash=8 2> /dev/null`.split.first

      new_file = File.join('src', 'bar', 'bla')
      begin
        FileUtils.touch(new_file)

        out = bosh_runner.run_in_current_dir('create release --force')
        release_manifest_1 = parse_release_manifest_path(out)
        expect(File).to exist(release_manifest_1)
      ensure
        FileUtils.rm_rf(new_file)
      end
      release_manifest = Psych.load_file(release_manifest_1)
      expect(release_manifest['commit_hash']).to eq commit_hash
      expect(release_manifest['uncommitted_changes']).to be(true)

      target_and_login
      bosh_runner.run_in_current_dir('upload release')
    end

    expect_output('releases', <<-OUT)
    +--------------+----------+-------------+
    | Name         | Versions | Commit Hash |
    +--------------+----------+-------------+
    | bosh-release | 0+dev.1  | #{commit_hash}+   |
    +--------------+----------+-------------+
    (+) Uncommitted changes

    Releases total: 1
    OUT
  end

  describe 'uploading a release that already exists' do
    before { target_and_login }

    context 'when the release is local' do
      let(:local_release_path) { spec_asset('valid_release.tgz') }
      before { bosh_runner.run("upload release #{local_release_path}") }

      context 'when using the --skip-if-exists flag' do
        it 'tells the user and does not exit as a failure' do
          output = bosh_runner.run("upload release #{local_release_path} --skip-if-exists")
          expect(output).to include("Release `appcloud/0.1' already exists. Skipping upload.")
        end
      end

      context 'when NOT using the --skip-if-exists flag' do
        it 'tells the user and does exit as a failure' do
          output, exit_code = bosh_runner.run("upload release #{local_release_path}", {
            failure_expected: true,
            return_exit_code: true,
          })
          expect(output).to include('This release version has already been uploaded')
          expect(exit_code).to eq(1)
        end
      end
    end

    context 'when the release is remote' do
      let(:file_server) { Bosh::Spec::LocalFileServer.new(spec_asset(''), file_server_port, logger) }
      let(:file_server_port) { current_sandbox.get_named_port('releases-repo') }

      before { file_server.start }
      after { file_server.stop }

      let(:release_url) { file_server.http_url("valid_release.tgz") }

      before { bosh_runner.run("upload release #{release_url}") }

      context 'when using the --skip-if-exists flag' do
        it 'tells the user and does not exit as a failure' do
          output = bosh_runner.run("upload release #{release_url} --skip-if-exists")
          expect(output).to include("release already exists > appcloud/0.1")
        end
      end

      context 'when NOT using the --skip-if-exists flag' do
        it 'tells the user and does exit as a failure' do
          output, exit_code = bosh_runner.run("upload release #{release_url}", {
            failure_expected: true,
            return_exit_code: true,
          })
          expect(output).to include("Release `appcloud/0.1' already exists")
          expect(exit_code).to eq(1)
        end
      end
    end
  end
end
