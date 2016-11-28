require 'spec_helper'

describe 'deliver rendered templates through nats', type: :integration do
  with_reset_sandbox_before_each(enable_nats_delivered_templates: true)

  let(:cloud_config) {Bosh::Spec::Deployments.simple_cloud_config}

  let(:manifest_hash) do
    Bosh::Spec::Deployments.test_release_manifest.merge(
      {
        'jobs' => [Bosh::Spec::Deployments.job_with_many_templates(
          name: 'our_instance_group',
          templates: [
            {'name' => 'job_1_with_many_properties',
             'properties' => job_properties
            }
          ],
          instances: 3
        )]
      })
  end

  let(:job_properties) do
    {
      'gargamel' => {
        'color' => 'GARGAMEL_COLOR_IS_NOT_BLUE'
      },
      'smurfs' => {
        'happiness_level' => 2000
      }
    }
  end

  it 'does NOT store rendered templates in the blobstore' do
    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

    running_vm = director.vm('our_instance_group', '0')
    template_hash = YAML.load(running_vm.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
    expect(template_hash['properties_list']['gargamel_color']).to eq('GARGAMEL_COLOR_IS_NOT_BLUE')

    zgrep_command = "zgrep GARGAMEL_COLOR_IS_NOT_BLUE #{current_sandbox.blobstore_storage_dir}/*"
    zgrep_output = `#{zgrep_command}`

    expect(zgrep_output.empty?).to be_truthy
  end
end
