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

    zgrep_output = `zgrep GARGAMEL_COLOR_IS_NOT_BLUE #{current_sandbox.blobstore_storage_dir}/*`

    expect(zgrep_output.empty?).to be_truthy
  end

  context 'when having multiple instance groups and jobs' do
    let(:job_2_properties) do
      {
        'gargamel' => {
          'color' => 'RED_IS_AZRIEL'
        },
        'smurfs' => {
          'happiness_level' => 150
        }
      }
    end

    let(:big_manifest_hash) do
      big_manifest_hash = Bosh::Spec::Deployments.simple_manifest
      big_manifest_hash.delete('resource_pools')
      big_manifest_hash['stemcells'] = [Bosh::Spec::Deployments.stemcell]
      big_manifest_hash['jobs'] = [{
                                 'name' => 'instance_group_1',
                                 'templates' => [{
                                                   'name' => 'job_1_with_many_properties',
                                                   'properties' => job_properties
                                                 },
                                                 {
                                                   'name' => 'job_2_with_many_properties',
                                                   'properties' => job_2_properties
                                                 },
                                                 {
                                                   'name' => 'errand1',
                                                   'properties' => { 'errand1' => { 'exit_code' => 10} }
                                                 }],
                                 'vm_type' => 'smurf-vm-type',
                                 'stemcell' => 'default',
                                 'instances' => 3,
                                 'networks' => [{ 'name' => 'a' }]
                               },{
                                'name' => 'instance_group_2',
                                'templates' => [{
                                                  'name' => 'job_1_with_many_properties',
                                                  'properties' => job_2_properties
                                                },
                                                {
                                                  'name' => 'job_2_with_many_properties',
                                                  'properties' => job_properties
                                                },
                                                {
                                                  'name' => 'errand1',
                                                  'properties' => { 'errand1' => { 'exit_code' => 5} }
                                                }],
                                'vm_type' => 'smurf-vm-type',
                                'stemcell' => 'default',
                                'instances' => 2,
                                'networks' => [{ 'name' => 'a' }]
                              }]
      big_manifest_hash
    end

    it 'should work as expected - change me please' do
      deploy_from_scratch(manifest_hash: big_manifest_hash, cloud_config_hash: cloud_config)

      running_instances = director.instances

      # =========================================
      # Instance Group 1
      instance_group_1_vm = running_instances.select{ |instance| instance.job_name == 'instance_group_1'}.first

      template_1_hash_1 = YAML.load(instance_group_1_vm.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
      expect(template_1_hash_1['properties_list']['gargamel_color']).to eq('GARGAMEL_COLOR_IS_NOT_BLUE')

      template_1_hash_2 = YAML.load(instance_group_1_vm.read_job_template('job_2_with_many_properties', 'properties_displayer.yml'))
      expect(template_1_hash_2['properties_list']['gargamel_color']).to eq('RED_IS_AZRIEL')

      errand_1_run_script = instance_group_1_vm.read_job_template('errand1', 'bin/run')
      expect(errand_1_run_script).to include('exit 10')

      # =========================================
      # Instance Group 2
      instance_group_2_vm = running_instances.select{ |instance| instance.job_name == 'instance_group_2'}.first

      template_2_hash_1 = YAML.load(instance_group_2_vm.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
      expect(template_2_hash_1['properties_list']['gargamel_color']).to eq('RED_IS_AZRIEL')

      template_2_hash_2 = YAML.load(instance_group_2_vm.read_job_template('job_2_with_many_properties', 'properties_displayer.yml'))
      expect(template_2_hash_2['properties_list']['gargamel_color']).to eq('GARGAMEL_COLOR_IS_NOT_BLUE')

      errand_2_run_script = instance_group_2_vm.read_job_template('errand1', 'bin/run')
      expect(errand_2_run_script).to include('exit 5')

      zegrep_output = `zegrep 'GARGAMEL_COLOR_IS_NOT_BLUE|RED_IS_AZRIEL' #{current_sandbox.blobstore_storage_dir}/*`
      expect(zegrep_output.empty?).to be_truthy
    end

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

      zgrep_output = `zgrep GARGAMEL_COLOR_IS_NOT_BLUE #{current_sandbox.blobstore_storage_dir}/*`
      expect(zgrep_output.empty?).to be_falsey
    end
  end
end
