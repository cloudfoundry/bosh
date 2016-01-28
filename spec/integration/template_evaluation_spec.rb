require 'spec_helper'

describe 'template', type: :integration do
  with_reset_sandbox_before_each

  it 'can access exposed attributes of an instance' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'] = [
      {
        'name' => 'id_job',
        'templates' => ['name' => 'id_job'],
        'resource_pool' => 'a',
        'instances' => 1,
        'networks' => [{
            'name' => 'a',
          }],
        'properties' => {},
      }
    ]
    deploy_from_scratch(manifest_hash: manifest_hash)

    id_vm = director.vm('id_job', '0')
    template = YAML.load(id_vm.read_job_template('id_job', 'config.yml'))
    expect(template['id']).to match /[a-f0-9\-]/
    expect(template['resource_pool']).to eq 'a'
  end


  it 'gives VMs the same id on `deploy --recreate`' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'] = [
      {
        'name' => 'id_job',
        'templates' => ['name' => 'id_job'],
        'resource_pool' => 'a',
        'instances' => 1,
        'networks' => [{
            'name' => 'a',
          }],
        'properties' => {},
      }
    ]

    deploy_from_scratch(manifest_hash: manifest_hash)

    id_vm = director.vm('id_job', '0')
    template = YAML.load(id_vm.read_job_template('id_job', 'config.yml'))
    original_id = template['id']
    expect(original_id).to match /[a-f0-9\-]/

    deploy_simple_manifest(manifest_hash: manifest_hash, recreate: true)
    id_vm = director.vm('id_job', '0')
    template = YAML.load(id_vm.read_job_template('id_job', 'config.yml'))
    new_id = template['id']
    expect(new_id).to match /[a-f0-9\-]/

    expect(new_id).to eq(original_id)
  end
end
