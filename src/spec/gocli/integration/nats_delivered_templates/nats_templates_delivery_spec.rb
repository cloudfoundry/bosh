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
    cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config
    cloud_config_hash['vm_types'] = [vm_type]
    cloud_config_hash
  end

  let(:manifest_hash) do
    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    manifest_hash['stemcells'] = [Bosh::Spec::Deployments.stemcell]
    manifest_hash['instance_groups'] = [{
       'name' => 'our_instance_group',
       'jobs' => [{
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

  it 'sanitizes agent_client upload_blob call in director debug logs' do
    deploy_output = deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

    task_id = deploy_output.match(/^Task (\d+)$/)[1]

    debug_output = bosh_runner.run("task --debug #{task_id}")
    upload_blob_debug_lines = debug_output.split("\n").select{ |line| line.include?('"method":"upload_blob"') }
    expect(upload_blob_debug_lines.count).to eq(6)

    upload_blob_debug_lines.each do |line|
      upload_blob_request = JSON.parse(line.split(/SENT: agent\.[0-9a-f]{8}-[0-9a-f-]{27} /)[1])
      expect(upload_blob_request['method']).to eq('upload_blob')
      expect(upload_blob_request['arguments'].size).to eq(1)
      expect(upload_blob_request['arguments'][0]['checksum']).to eq('<redacted>')
      expect(upload_blob_request['arguments'][0]['payload']).to eq('<redacted>')
    end

    running_instance = director.instances.select{ |instance| instance.job_name == 'our_instance_group'}.first
    template_hash = YAML.load(running_instance.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
    expect(template_hash['properties_list']['gargamel_color']).to eq('GARGAMEL_COLOR_IS_NOT_BLUE')
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
      big_manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
      big_manifest_hash['instance_groups'] = [{
                                 'name' => 'instance_group_1',
                                 'jobs' => [{
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
                                'jobs' => [{
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

    it 'should work as expected' do
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
    with_reset_sandbox_before_each(enable_nats_delivered_templates: true, nats_allow_legacy_clients: true)

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

  context 'when agent fails to open blob for writing' do
    with_reset_sandbox_before_each(enable_nats_delivered_templates: true, nats_allow_legacy_clients: true)

    let(:vm_type) do
      {
        'name' => 'smurf-vm-type',
        'cloud_properties' => {'legacy_agent_path' => get_legacy_agent_path('upload-blob-action-error-file-not-found')}
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
