require 'spec_helper'

describe 'local template properties', type: :integration do
  with_reset_sandbox_before_each

  let(:manifest) do
    SharedSupport::DeploymentManifestHelper.manifest_with_release.merge(
      'instance_groups' => [
        SharedSupport::DeploymentManifestHelper.instance_group_with_many_jobs(
          name: 'job_with_templates_having_properties',
          jobs: [
            {
              'name' => 'job_1_with_many_properties',
              'release' => 'bosh-release',
              'properties' => {
                'smurfs' => {
                  'color' => 'red',
                },
                'gargamel' => {
                  'color' => 'black',
                },
              },
            },
            {
              'name' => 'job_2_with_many_properties',
              'release' => 'bosh-release',
              'properties' => {
                'snoopy' => 'happy',
                'smurfs' => {
                  'color' => 'yellow',
                },
                'gargamel' => {
                  'color' => 'blue',
                },
              },
            },
          ],
          instances: 1,
        ),
      ],
    )
  end

  before do
    upload_cloud_config(cloud_config_hash: SharedSupport::DeploymentManifestHelper.simple_cloud_config)
    upload_stemcell
    create_and_upload_test_release
  end

  it 'these templates should use the properties defined in their scope' do
    deploy(manifest_hash: manifest)
    target_instance = director.instance('job_with_templates_having_properties', '0')
    template1 = YAML.load(target_instance.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
    template2 = YAML.load(target_instance.read_job_template('job_2_with_many_properties', 'properties_displayer.yml'))

    expect(template1['properties_list']['smurfs_color']).to eq('red')
    expect(template1['properties_list']['gargamel_color']).to eq('black')

    expect(template2['properties_list']['smurfs_color']).to eq('yellow')
    expect(template2['properties_list']['gargamel_color']).to eq('blue')
  end

  it 'should update the job when template properties change' do
    deploy(manifest_hash: manifest)

    manifest = SharedSupport::DeploymentManifestHelper.manifest_with_release.merge(
      'instance_groups' => [
        SharedSupport::DeploymentManifestHelper.instance_group_with_many_jobs(
          name: 'job_with_templates_having_properties',
          jobs: [
            {
              'name' => 'job_1_with_many_properties',
              'release' => 'bosh-release',
              'properties' => {
                'smurfs' => {
                  'color' => 'reddish',
                },
                'gargamel' => {
                  'color' => 'blackish',
                },
              },
            },
            {
              'name' => 'job_2_with_many_properties',
              'release' => 'bosh-release',
              'properties' => {
                'snoopy' => 'happy',
                'smurfs' => {
                  'color' => 'yellow',
                },
                'gargamel' => {
                  'color' => 'blue',
                },
              },
            },
          ],
          instances: 1,
        ),
      ],
    )

    output = deploy(manifest_hash: manifest)
    expect(output).to include('Updating instance job_with_templates_having_properties')
  end

  it 'should not update the job when template properties are the same' do
    deploy(manifest_hash: manifest)
    output = deploy(manifest_hash: manifest)
    expect(output).to_not include('Updating instance job_with_templates_having_properties')
  end

  context 'when the template has local properties defined but missing some of them' do
    let(:manifest) do
      SharedSupport::DeploymentManifestHelper.manifest_with_release.merge(
        'instance_groups' => [
          SharedSupport::DeploymentManifestHelper.instance_group_with_many_jobs(
            name: 'job_with_templates_having_properties',
            jobs: [
              {
                'name' => 'job_1_with_many_properties',
                'release' => 'bosh-release',
                'properties' => {
                  'smurfs' => {
                    'color' => 'red',
                  },
                },
              },
              {
                'name' => 'job_2_with_many_properties',
                'release' => 'bosh-release',
                'properties' => {
                  'snoopy' => 'happy',
                  'smurfs' => {
                    'color' => 'yellow',
                  },
                  'gargamel' => {
                    'color' => 'black',
                  },
                },
              },
            ],
            instances: 1,
          ),
        ],
      )
    end

    it 'should fail even if the properties are defined outside the template scope' do
      output, exit_code = deploy(manifest_hash: manifest, failure_expected: true, return_exit_code: true)

      expect(exit_code).to_not eq(0)
      expect(output).to include <<~OUTPUT.strip
        Error: Unable to render instance groups for deployment. Errors are:
          - Unable to render jobs for instance group 'job_with_templates_having_properties'. Errors are:
            - Unable to render templates for job 'job_1_with_many_properties'. Errors are:
              - Error filling in template 'properties_displayer.yml.erb' (line 4: Can't find property '["gargamel.color"]')
      OUTPUT
    end
  end

  context 'when same template is referenced in multiple deployment jobs' do
    let(:manifest) do
      SharedSupport::DeploymentManifestHelper.manifest_with_release.merge(
        'instance_groups' => [
          SharedSupport::DeploymentManifestHelper.instance_group_with_many_jobs(
            name: 'worker_1',
            jobs: [
              {
                'name' => 'job_1_with_many_properties',
                'release' => 'bosh-release',
                'properties' => {
                  'smurfs' => {
                    'color' => 'pink',
                  },
                  'gargamel' => {
                    'color' => 'orange',
                  },
                },
              },
              {
                'name' => 'job_2_with_many_properties',
                'release' => 'bosh-release',
                'properties' => {
                  'smurfs' => {
                    'color' => 'yellow',
                  },
                  'gargamel' => {
                    'color' => 'green',
                  },
                },
              },
            ],
            instances: 1,
          ),
          SharedSupport::DeploymentManifestHelper.instance_group_with_many_jobs(
            name: 'worker_2',
            jobs: [
              {
                'name' => 'job_1_with_many_properties',
                'release' => 'bosh-release',
                'properties' => {
                  'smurfs' => {
                    'color' => 'navy',
                  },
                  'gargamel' => {
                    'color' => 'red',
                  },
                },
              },
              {
                'name' => 'job_2_with_many_properties',
                'release' => 'bosh-release',
                'properties' => {
                  'snoopy' => 'happy',
                  'smurfs' => {
                    'color' => 'brown',
                  },
                  'gargamel' => {
                    'color' => 'grey',
                  },
                },
              },
            ],
            instances: 1,
          ),
        ],
      )
    end

    it 'should not expose the local properties across deployment jobs' do
      deploy(manifest_hash: manifest)

      target_vm1 = director.instance('worker_1', '0')
      template1_in_worker1 = YAML.load(target_vm1.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
      template2_in_worker1 = YAML.load(target_vm1.read_job_template('job_2_with_many_properties', 'properties_displayer.yml'))

      target_vm2 = director.instance('worker_2', '0')
      template1_in_worker2 = YAML.load(target_vm2.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
      template2_in_worker2 = YAML.load(target_vm2.read_job_template('job_2_with_many_properties', 'properties_displayer.yml'))

      expect(template1_in_worker1['properties_list']['smurfs_color']).to eq('pink')
      expect(template1_in_worker1['properties_list']['gargamel_color']).to eq('orange')
      expect(template2_in_worker1['properties_list']['smurfs_color']).to eq('yellow')
      expect(template2_in_worker1['properties_list']['gargamel_color']).to eq('green')

      expect(template1_in_worker2['properties_list']['smurfs_color']).to eq('navy')
      expect(template1_in_worker2['properties_list']['gargamel_color']).to eq('red')
      expect(template2_in_worker2['properties_list']['smurfs_color']).to eq('brown')
      expect(template2_in_worker2['properties_list']['gargamel_color']).to eq('grey')
    end

    it 'should only complain about non-property satisfied template when missing properties' do
      manifest['instance_groups'][1]['jobs'][1]['properties'] = {}

      output, exit_code = deploy(manifest_hash: manifest, return_exit_code: true, failure_expected: true)

      expect(exit_code).to_not eq(0)
      expect(output).to include <<~OUTPUT.strip
        Error: Unable to render instance groups for deployment. Errors are:
          - Unable to render jobs for instance group 'worker_2'. Errors are:
            - Unable to render templates for job 'job_2_with_many_properties'. Errors are:
              - Error filling in template 'properties_displayer.yml.erb' (line 4: Can't find property '["gargamel.color"]')
      OUTPUT
    end
  end
end
