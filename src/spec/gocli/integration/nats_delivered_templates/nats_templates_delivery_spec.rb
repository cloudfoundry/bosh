require_relative '../../spec_helper'

describe 'deliver rendered templates through nats', type: :integration do
  with_reset_sandbox_before_each(enable_nats_delivered_templates: true)

  let(:vm_type) do
    {
      'name' => 'smurf-vm-type',
      'cloud_properties' => {}
    }
  end

  let(:cloud_config) do
    cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
    cloud_config_hash.delete('resource_pools')

    cloud_config_hash['vm_types'] = [vm_type]
    cloud_config_hash
  end

  let(:manifest_hash) do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash.delete('resource_pools')
    manifest_hash['stemcells'] = [Bosh::Spec::Deployments.stemcell]
    manifest_hash['jobs'] = [{
       'name' => 'our_instance_group',
       'templates' => [{
                    'name' => 'job_1_with_many_properties',
                    'properties' => job_properties
                  }],
       'vm_type' => 'smurf-vm-type',
       'stemcell' => 'default',
       'instances' => 3,
       'networks' => [{ 'name' => 'a' }]
     }]
    manifest_hash
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

    running_instance = director.instances.select{ |instance| instance.job_name == 'our_instance_group'}.first
    template_hash = YAML.load(running_instance.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
    expect(template_hash['properties_list']['gargamel_color']).to eq('GARGAMEL_COLOR_IS_NOT_BLUE')

    zgrep_command = "zgrep GARGAMEL_COLOR_IS_NOT_BLUE #{current_sandbox.blobstore_storage_dir}/*"
    zgrep_output = `#{zgrep_command}`

    expect(zgrep_output.empty?).to be_truthy
  end

  context 'when agent does not support handling templates through nats' do
    let(:vm_type) do
      {
        'name' => 'smurf-vm-type',
        'cloud_properties' => {'legacy_agent_path' => get_legacy_agent_path('no-upload-blob-action-e82bdd1c')}
      }
    end

    it 'should fallback to storing in the default blobstore' do
      deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

      running_instance = director.instances.select{ |instance| instance.job_name == 'our_instance_group'}.first
      template_hash = YAML.load(running_instance.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
      expect(template_hash['properties_list']['gargamel_color']).to eq('GARGAMEL_COLOR_IS_NOT_BLUE')

      zgrep_command = "zgrep GARGAMEL_COLOR_IS_NOT_BLUE #{current_sandbox.blobstore_storage_dir}/*"
      zgrep_output = `#{zgrep_command}`

      expect(zgrep_output.empty?).to be_falsey
    end
  end
end
