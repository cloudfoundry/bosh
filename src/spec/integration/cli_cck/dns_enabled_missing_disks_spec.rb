require 'spec_helper'

describe 'cli: cloudcheck', type: :integration do
  let(:manifest) { Bosh::Spec::Deployments.simple_manifest_with_instance_groups }
  let(:director_name) { current_sandbox.director_name }
  let(:deployment_name) { manifest['name'] }
  let(:runner) { bosh_runner_in_work_dir(ClientSandbox.test_release_dir) }

  def prepend_namespace(key)
    "/#{director_name}/#{deployment_name}/#{key}"
  end

  context 'with dns enabled' do
    with_reset_sandbox_before_each

    let(:num_instances) { 3 }

    before do
      bosh_runner.run("upload-stemcell #{asset_path('valid_stemcell_with_api_version.tgz')}")
      upload_cloud_config(cloud_config_hash: Bosh::Spec::Deployments.simple_cloud_config)
      create_and_upload_test_release

      manifest['instance_groups'][0]['persistent_disk'] = 100
      manifest['instance_groups'][0]['instances'] = num_instances

      deploy(manifest_hash: manifest)

      expect(runner.run('cloud-check --report', deployment_name: 'simple')).to match(regexp('0 problems'))
    end

    context 'deployment has missing disks' do
      before do
        current_sandbox.cpi.delete_disk(current_sandbox.cpi.disk_cids.first)
      end

      it 'provides resolution options' do
        cloudcheck_response = scrub_randoms(bosh_run_cck_with_resolution(1))
        expect(cloudcheck_response).to_not match(regexp('0 problems'))
        expect(cloudcheck_response).to match(regexp('1 missing'))
        expect(cloudcheck_response).to match(
          regexp("Disk 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx' (foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx, 100M) is missing"),
        )
        expect(cloudcheck_response).to match(regexp('1: Skip for now
2: Delete disk reference (DANGEROUS!)'))
      end

      it 'deletes disk reference when delete_disk_reference is set and passes correct stemcell_api_version in the CPI call' do
        cloudcheck_response = scrub_randoms(
          bosh_runner.run(
            'cck --resolution non-matching-resolution1 --resolution delete_disk_reference --resolution non-matching-resolution2',
            deployment_name: 'simple',
          ),
        )

        expect(cloudcheck_response).to_not match(regexp('0 problems'))
        expect(cloudcheck_response).to match(regexp('1 missing'))
        expect(cloudcheck_response).to match(
          regexp("Disk 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx' (foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx, 100M) is missing"),
        )

        detach_disk_cpi_invocations = current_sandbox.cpi.invocations_for_method('detach_disk')
        expect(detach_disk_cpi_invocations.count).to eq(1)
        detach_disk_cpi_invocations.each do |attach_disk_invocation|
          expect(attach_disk_invocation.method_name).to eq('detach_disk')
          expect(attach_disk_invocation.context).to match(
            'director_uuid' => kind_of(String),
            'request_id' => kind_of(String),
            'vm' => {
              'stemcell' => {
                'api_version' => 25,
              },
            },
          )
        end
      end
    end
  end

  def bosh_run_cck_with_resolution(num_errors, option = 1)
    output = ''
    bosh_runner.run_interactively('cck', deployment_name: 'simple') do |runner|
      (1..num_errors).each do
        expect(runner).to have_output 'Skip for now'

        runner.send_keys option.to_s
      end

      expect(runner).to have_output 'Continue?'
      runner.send_keys 'y'

      expect(runner).to have_output 'Succeeded'
      output = runner.output
    end
    output
  end

  def scrub_text_random_ids(text)
    text.gsub(/[0-9a-f]{8}-[0-9a-f-]{27}/, 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx')
  end

  def scrub_text_disk_ids(text)
    text.gsub(/[0-9a-z]{32}/, 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx')
  end

  def scrub_randoms(text)
    scrub_vm_cid(scrub_index(scrub_text_disk_ids(scrub_text_random_ids(text))))
  end

  def scrub_vm_cid(text)
    text.gsub(/'\d+'/, "'xxx'")
  end

  def scrub_index(text)
    text.gsub(/\(\d+\)/, '(x)')
  end
end
