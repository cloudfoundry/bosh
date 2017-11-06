require 'securerandom'
require_relative '../spec_helper'

describe 'package dependencies', type: :integration do
  with_reset_sandbox_before_each

  let(:manifest_hash) do
    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    manifest_hash['releases'].first['version'] = 'latest'
    manifest_hash['instance_groups'] = [
      {
        'name'          => 'transitive_deps',
        'jobs'          => ['name' => 'transitive_deps'],
        'vm_type' => 'a',
        'instances'     => 1,
        'networks'      => [{ 'name' => 'a' }],
        'stemcell' => 'default',
      }
    ]
    manifest_hash
  end

  it 'recompiles packages when a transitive dependency changes' do
    Dir.chdir(ClientSandbox.test_release_dir) do
      output = deploy_from_scratch(manifest_hash: manifest_hash)
      expect(output).to include('Compiling packages: c/')
      expect(output).to include('Compiling packages: b/')
      expect(output).to include('Compiling packages: a/')

      with_changed_release_source('c') do
        bosh_runner.run_in_current_dir('create-release --force')
        bosh_runner.run_in_current_dir('upload-release')
      end

      output = deploy_simple_manifest(manifest_hash: manifest_hash)
      expect(output).to include('Compiling packages: c/')
      expect(output).to include('Compiling packages: b/')
      expect(output).to include('Compiling packages: a/')
    end
  end

  context 'with a copy of the test release' do
    let(:tmpdir) { Dir.mktmpdir(prefix_suffix='bosh_test_release') }
    after { FileUtils.rm_r(tmpdir) }

    let(:temp_release_dir) { File.join(tmpdir, 'workspace') }
    before { FileUtils.cp_r(ClientSandbox.test_release_dir, temp_release_dir) }

    it 'survives removal of a transitive dependency' do
      Dir.chdir(temp_release_dir) do
        bosh_runner.run_in_current_dir('create-release')
        bosh_runner.run_in_current_dir('upload-release')
        upload_stemcell
        upload_cloud_config
        deploy_simple_manifest(manifest_hash: manifest_hash)

        # update 'b' spec to remove dependency on 'c'
        b_spec_file = File.join('packages', 'b', 'spec')
        b_spec_hash = YAML.load_file(b_spec_file)
        b_spec_hash['dependencies'] = []
        File.open(b_spec_file, 'w') { |f| f.write(YAML.dump(b_spec_hash)) }

        # force 'b' to recompile
        FileUtils.touch(File.join('src', 'b', SecureRandom.uuid))

        # delete 'c'
        FileUtils.remove_dir(File.join('packages', 'c'))

        bosh_runner.run_in_current_dir('create-release --force')
        bosh_runner.run_in_current_dir('upload-release')

        deploy_simple_manifest(manifest_hash: manifest_hash)
      end
    end
  end

  def with_changed_release_source(src_name)
    new_file = File.join('src', src_name, SecureRandom.uuid)
    begin
      FileUtils.touch(new_file)
      yield
    ensure
      FileUtils.rm_rf(new_file)
    end
  end
end
