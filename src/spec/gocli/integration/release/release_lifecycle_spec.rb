require 'securerandom'
require_relative '../../spec_helper'

describe 'release lifecycle', type: :integration do
  include Bosh::Spec::CreateReleaseOutputParsers
  with_reset_sandbox_before_each

  it 'creates and deploys a new final release with a user defined version' do
    commit_hash = ''

    Dir.chdir(ClientSandbox.test_release_dir) do
      File.open('config/final.yml', 'w') do |final|
        final.puts YAML.dump(
          'final_name' => 'bosh-release',
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

      out = bosh_runner.run_in_current_dir('create-release --force')
      expect(parse_release_version(out)).to eq('0+dev.1')
      expect(File.exists?(File.join(Dir.pwd, 'dev_releases', 'bosh-release', 'bosh-release-0+dev.1.yml'))).to eq(true)

      out = bosh_runner.run_in_current_dir('create-release --final --force --version 1.0')
      expect(parse_release_version(out)).to eq('1.0')
      expect(File.exists?(File.join(Dir.pwd, 'releases', 'bosh-release', 'bosh-release-1.0.yml'))).to eq(true)

      with_changed_release do
        out = bosh_runner.run_in_current_dir('create-release --force')
        expect(parse_release_version(out)).to eq('1.0+dev.1')
        expect(File.exists?(File.join(Dir.pwd, 'dev_releases', 'bosh-release', 'bosh-release-1.0+dev.1.yml'))).to eq(true)

        out = bosh_runner.run_in_current_dir('create-release --final --force --version 2.0')
        expect(parse_release_version(out)).to eq('2.0')
        expect(File.exists?(File.join(Dir.pwd, 'releases', 'bosh-release', 'bosh-release-2.0.yml'))).to eq(true)
      end
      bosh_runner.run_in_current_dir('upload-release')

      commit_hash = `git show-ref --head --hash=7 2> /dev/null`.split.first
    end

    bosh_runner.run("upload-stemcell #{spec_asset('valid_stemcell.tgz')}")

    cloud_config_manifest = yaml_file('cloud_manifest', Bosh::Spec::Deployments.simple_cloud_config)
    bosh_runner.run("update-cloud-config #{cloud_config_manifest.path}")

    manifest = Bosh::Spec::Deployments.simple_manifest
    manifest['releases'].first['version'] = 'latest'

    deployment_manifest = yaml_file('deployment_manifest', manifest)

    bosh_runner.run("deploy #{deployment_manifest.path}", deployment_name: 'simple')

    expect_table('releases', [{'name' => 'bosh-release', 'version' => '2.0*', 'commit_hash' => "#{commit_hash}+"}])
  end

  # ~57s
  it 'release lifecycle: create, upload, update (w/sparse upload), delete' do
    commit_hash = ''

    Dir.chdir(ClientSandbox.test_release_dir) do
      commit_hash = `git show-ref --head --hash=7 2> /dev/null`.split.first

      out = bosh_runner.run_in_current_dir('create-release')
      expect(parse_release_version(out)).to eq('0+dev.1')

      bosh_runner.run_in_current_dir('upload-release')

      with_changed_release do
        #  In an ephemeral git repo
        `git add .`
        `git commit -m 'second dev release'`

        bosh_runner.run_in_current_dir('create-release')
      end

      bosh_runner.run_in_current_dir('upload-release dev_releases/bosh-release/bosh-release-0+dev.2.yml')
    end

    table_output = table(bosh_runner.run('releases', json: true))
    expect(table_output).to include({'name'=> 'bosh-release', 'version'=> '0+dev.2', 'commit_hash'=> String})
    expect(table_output).to include({'name'=> 'bosh-release', 'version'=> '0+dev.1', 'commit_hash'=> String})
    expect(table_output.length).to eq(2)

    bosh_runner.run('delete-release bosh-release/0+dev.2')
    expect_table('releases', [{'name' => 'bosh-release', 'version' => '0+dev.1', 'commit_hash' => "#{commit_hash}"}])

    bosh_runner.run('delete-release bosh-release/0+dev.1')
    expect_table('releases', [])
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
