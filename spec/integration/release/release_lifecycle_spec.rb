require 'securerandom'
require 'spec_helper'

describe 'release lifecycle', type: :integration do
  include Bosh::Spec::CreateReleaseOutputParsers
  with_reset_sandbox_before_each

  it 'creates and deploys a new final release with a user defined version' do
    target_and_login

    commit_hash = ''

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

      out = bosh_runner.run_in_current_dir('create release --force')
      expect(parse_release_version(out)).to eq('0+dev.1')
      expect(parse_release_manifest_path(out)).to eq(
        File.join(Dir.pwd, 'dev_releases', 'bosh-release', 'bosh-release-0+dev.1.yml')
      )

      out = bosh_runner.run_in_current_dir('create release --final --force --version 1.0')
      expect(parse_release_version(out)).to eq('1.0')
      expect(parse_release_manifest_path(out)).to eq(
        File.join(Dir.pwd, 'releases', 'bosh-release', 'bosh-release-1.0.yml')
      )

      with_changed_release do
        out = bosh_runner.run_in_current_dir('create release --force')
        expect(parse_release_version(out)).to eq('1.0+dev.1')
        expect(parse_release_manifest_path(out)).to eq(
          File.join(Dir.pwd, 'dev_releases', 'bosh-release', 'bosh-release-1.0+dev.1.yml')
        )

        out = bosh_runner.run_in_current_dir('create release --final --force --version 2.0')
        expect(parse_release_version(out)).to eq('2.0')
        expect(parse_release_manifest_path(out)).to eq(
          File.join(Dir.pwd, 'releases', 'bosh-release', 'bosh-release-2.0.yml')
        )
      end
      bosh_runner.run_in_current_dir('upload release')

      commit_hash = `git show-ref --head --hash=8 2> /dev/null`.split.first
    end

    bosh_runner.run("upload stemcell #{spec_asset('valid_stemcell.tgz')}")

    cloud_config_manifest = yaml_file('cloud_manifest', Bosh::Spec::Deployments.simple_cloud_config)
    bosh_runner.run("update cloud-config #{cloud_config_manifest.path}")

    manifest = Bosh::Spec::Deployments.simple_manifest
    manifest['releases'].first['version'] = 'latest'

    deployment_manifest = yaml_file('deployment_manifest', manifest)
    bosh_runner.run("deployment #{deployment_manifest.path}")

    bosh_runner.run('deploy')

    expect_output('releases', <<-OUT)
    +--------------+----------+-------------+
    | Name         | Versions | Commit Hash |
    +--------------+----------+-------------+
    | bosh-release | 2.0*     | #{commit_hash}+   |
    +--------------+----------+-------------+
    (*) Currently deployed
    (+) Uncommitted changes

    Releases total: 1
    OUT
  end

  # ~57s
  it 'release lifecycle: create, upload, update (w/sparse upload), delete' do
    commit_hash = ''

    Dir.chdir(ClientSandbox.test_release_dir) do
      commit_hash = `git show-ref --head --hash=8 2> /dev/null`.split.first

      out = bosh_runner.run_in_current_dir('create release')
      release_manifest_1 = parse_release_manifest_path(out)
      expect(File).to exist(release_manifest_1)

      target_and_login
      bosh_runner.run_in_current_dir("upload release #{release_manifest_1}")

      out = with_changed_release do
        #  In an ephemeral git repo
        `git add .`
        `git commit -m 'second dev release'`
        expect(File).to exist(release_manifest_1)

        bosh_runner.run_in_current_dir('create release')
      end
      release_manifest_2 = parse_release_manifest_path(out)
      expect(File).to exist(release_manifest_2)

      out = bosh_runner.run_in_current_dir("upload release #{release_manifest_2}")
      expect(out).not_to match regexp('Checking if can repack')
      expect(out).not_to match regexp('Release repacked')
      expect(out).to match /Release uploaded/
    end

    out = bosh_runner.run('releases')
    expect(out).to match /releases total: 1/i
    expect(out).to match /bosh-release.+0\+dev\.1.*0\+dev\.2/m

    bosh_runner.run('delete release bosh-release 0+dev.2')
    expect_output('releases', <<-OUT)
    +--------------+----------+-------------+
    | Name         | Versions | Commit Hash |
    +--------------+----------+-------------+
    | bosh-release | 0+dev.1  | #{commit_hash}    |
    +--------------+----------+-------------+

    Releases total: 1
    OUT

    bosh_runner.run('delete release bosh-release 0+dev.1')
    expect_output('releases', <<-OUT )
    No releases
    OUT
  end

  it 'verifies a sample valid release', no_reset: true do
    release_filename = spec_asset('test_release.tgz')
    out = bosh_runner.run("verify release #{release_filename}")
    expect(out).to match(regexp("`#{release_filename}' is a valid release"))
  end

  it 'points to an error on invalid release', no_reset: true do
    release_filename = spec_asset('release_invalid_checksum.tgz')
    out = bosh_runner.run("verify release #{release_filename}", failure_expected: true)
    expect(out).to match(regexp("`#{release_filename}' is not a valid release"))
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
