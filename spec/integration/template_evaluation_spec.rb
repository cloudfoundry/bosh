require 'spec_helper'

describe 'template', type: :integration do
  with_reset_sandbox_before_each

  it 'can access the id of an instance' do
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

    id_vm = director.vm('id_job/0')
    template = YAML.load(id_vm.read_job_template('id_job', 'config.yml'))
    puts template.inspect
    expect(template['id']).to match /[a-f0-9\-]/
  end
end
