require 'securerandom'
require 'spec_helper'

describe 'package dependencies', type: :integration do
  with_reset_sandbox_before_each

  it 'recompiles packages when a transitive dependency changes' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['releases'].first['version'] = 'latest'
    manifest_hash['resource_pools'].first.delete('size')
    manifest_hash['jobs'] = [
      {
        'name'          => 'transitive_deps',
        'template'      => 'transitive_deps',
        'resource_pool' => 'a',
        'instances'     => 1,
        'networks'      => [{ 'name' => 'a' }],
      }
    ]
    output = deploy_simple(manifest_hash: manifest_hash)
    expect(output).to include('Started compiling packages > c')
    expect(output).to include('Started compiling packages > b')
    expect(output).to include('Started compiling packages > a')

    Dir.chdir(TEST_RELEASE_DIR) do
      with_changed_release_source('c') do
        bosh_runner.run_in_current_dir('create release --force')
        bosh_runner.run_in_current_dir('upload release')
      end
    end

    output = deploy_simple_manifest(manifest_hash: manifest_hash)
    expect(output).to include('Started compiling packages > c')
    expect(output).to include('Started compiling packages > b')
    expect(output).to include('Started compiling packages > a')
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
