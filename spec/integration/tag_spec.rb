require 'spec_helper'
require 'fileutils'

describe 'Tag', type: :integration do
  with_reset_sandbox_before_each

  let(:cloud_config) { Bosh::Spec::Deployments.simple_cloud_config }

  before do
    prepare_sandbox
    target_and_login
    upload_cloud_config
    upload_stemcell
    create_and_upload_test_release
  end

  let(:deployment_name) { 'simple.tag' }
  let(:canonical_deployment_name) { 'simpletag' }
  let(:tags) {
    {'tags' => [{
      'key' => 'tag1',
      'value' => 'value1'
    }]
    }
  }

  context 'simple one VM deployment' do
    it 'creates a VM with tags ' do
      manifest = generate_manifest

      deploy_simple_manifest(manifest_hash: manifest)
      director.wait_for_first_available_vm
      check_most_recent_tags('tag', tags)
    end
  end

  context 'updated manifest' do
    it 'does not update tags without recreating' do
      manifest = generate_manifest
      deploy_simple_manifest(manifest_hash: manifest)
      director.wait_for_first_available_vm
      check_most_recent_tags('tag', tags)

      manifest['tags'] << {'key' => 'tag2', 'value' => 'value2'}

      deploy_simple_manifest(manifest_hash: manifest)
      director.wait_for_first_available_vm
      check_most_recent_tags('tag', {'tags' => [{'key' => 'tag1', 'value' => 'value1'}]})
    end
  end

  context 'with resurrection' do
    it 'recreates a VM with tags' do
      manifest = generate_manifest

      deploy_simple_manifest(manifest_hash: manifest)

      current_sandbox.cpi.vm_cids.each do |vm_cid|
        current_sandbox.cpi.delete_vm(vm_cid)
      end

      director.wait_for_first_available_vm
      check_most_recent_tags('tag', tags)
    end
  end

  context 'with cck' do
    let(:runner) { bosh_runner_in_work_dir(ClientSandbox.test_release_dir) }

    it 'recreates a VM with tags' do
      manifest = generate_manifest
      deploy_simple_manifest(manifest_hash: manifest)

      current_sandbox.cpi.vm_cids.each do |vm_cid|
        current_sandbox.cpi.delete_vm(vm_cid)
      end

      cloudcheck_response = bosh_run_cck_with_auto
      expect(cloudcheck_response).to match(regexp('missing.'))
      expect(cloudcheck_response).to match(regexp('Applying resolutions...'))
      expect(cloudcheck_response).to match(regexp('Cloudcheck is finished'))
      expect(cloudcheck_response).to_not match(regexp('No problems found'))
      expect(cloudcheck_response).to_not match(regexp('1. Skip for now
  2. Reboot VM
  3. Recreate VM using last known apply spec
  4. Delete VM
  5. Delete VM reference (DANGEROUS!)'))

      expect(runner.run('cloudcheck --report')).to match(regexp('No problems found'))

      check_most_recent_tags('tag', tags)
    end
  end

  private

  def generate_manifest
    manifest_deployment = Bosh::Spec::Deployments.test_release_manifest
    manifest_deployment.merge!(
      {
        'update' => {
          'canaries' => 2,
          'canary_watch_time' => 4000,
          'max_in_flight' => 2,
          'update_watch_time' => 20
        },

        'jobs' => [Bosh::Spec::Deployments.simple_job(
          name: 'tag',
          instances: 1)]
      })

    manifest_deployment.merge!(tags)
    manifest_deployment
  end

  def check_most_recent_tags(job_name, expected_tags)
    found_tags = false
    all_requests_file = File.open(File.join(current_sandbox.cloud_storage_dir, 'cpi_inputs', 'all_requests'))
    all_requests_file.readlines.reverse.each do |line|
      line_json = JSON.parse(line)
      if line_json['method_name'] == 'set_vm_metadata' && line_json['inputs']['metadata']['job'] == job_name
        expected_tags['tags'].each do |tag|
          expect(line_json['inputs']['metadata']).to include(tag['key'])
          expect(line_json['inputs']['metadata'][tag['key']]).to eq(tag['value'])
        end
        found_tags = true
        break
      end
    end
    expect(found_tags).to eq(true), 'Could not find any tags for job'
  end

  def bosh_run_cck_with_resolution(num_errors, option=1)
    resolution_selections = "#{option}\n"*num_errors + "yes"
    output = `echo "#{resolution_selections}" | bosh -c #{ClientSandbox.bosh_config} cloudcheck`
    if $?.exitstatus != 0
      fail("Cloud check failed, output: #{output}")
    end
    output
  end

  def bosh_run_cck_with_auto
    output = `bosh -c #{ClientSandbox.bosh_config} cloudcheck --auto`
    if $?.exitstatus != 0
      fail("Cloud check failed, output: #{output}")
    end
    output
  end
end
