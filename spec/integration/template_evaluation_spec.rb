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

  it 'prints all template evalution errors when there are errors in multiple templates' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'] = [
        {
            'name' => 'foobar_with_bad_properties',
            'templates' => ['name' => 'foobar_with_bad_properties'],
            'resource_pool' => 'a',
            'instances' => 1,
            'networks' => [{
                               'name' => 'a',
                           }],
            'properties' => {},
        }
    ]

    output = deploy_from_scratch(manifest_hash: manifest_hash, failure_expected: true)

    expect(output).to include("Error 100: Unable to render jobs for deployment. Errors are:
   - \"Unable to render templates for job foobar_with_bad_properties. Errors are:
     - \"Error filling in template `foobar_ctl' for `foobar_with_bad_properties/0' (line 8: Can't find property `[\"test_property\"]')\"
     - \"Error filling in template `drain.erb' for `foobar_with_bad_properties/0' (line 4: Can't find property `[\"dynamic_drain_wait1\"]')\"\"")
  end
end
