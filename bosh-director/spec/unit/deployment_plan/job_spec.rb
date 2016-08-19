require 'spec_helper'

describe Bosh::Director::DeploymentPlan::Job do
  # Currently this class is tested mostly in DeploymentPlan::ReleaseVersion spec.
  # In the future these tests can be migrated to here.
  describe '#add_link_from_manifest' do
    subject(:job) { described_class.new(nil, 'foo') }


    context 'given properly formated arguments' do
      before {
        job.add_link_from_release('job_name', 'provides', 'link_name', {'from' => 'link_name'})
        job.add_link_from_manifest('job_name', 'provides', 'link_name', {'properties'=>['plant'], 'from'=>'link_name'})
      }
      it 'should populate link_infos' do
        expect(job.link_infos).to eq({'job_name' =>{'provides' =>{'link_name' =>{'properties' =>['plant'], 'from' => 'link_name'}}}})
      end
    end

    context 'given incorrect manual configuration of consume link' do
      it 'should throw an error' do
        link_config = {'name'=>'link_name','type'=>'type', 'instances' => 'something', 'from'=>'link_name'}

        expect{
          job.add_link_from_manifest('job_name', 'consumes', 'link_name', link_config)
        }.to raise_error(/Cannot specify both 'instances' and 'from' keys for link 'link_name' in job 'foo' in instance group 'job_name'./)
      end

      it 'should throw an error' do
        link_config = {'name'=>'link_name','type'=>'type', 'properties' => 'something', 'from'=>'link_name'}

        expect{
          job.add_link_from_manifest('job_name', 'consumes', 'link_name', link_config)
        }.to raise_error(/Cannot specify both 'properties' and 'from' keys for link 'link_name' in job 'foo' in instance group 'job_name'.
Cannot specify 'properties' without 'instances' for link 'link_name' in job 'foo' in instance group 'job_name'./)
      end
    end

    context 'using restricted keys for links in the deployment manifest' do
      it 'should throw an error when "name" key is provided' do
        link_config = {'name'=>'link_name', 'from'=>'link_name'}

        expect { job.add_link_from_manifest('job_name', 'consumes', 'link_name', link_config) }.to raise_error(/Cannot specify 'name' or 'type' properties in the manifest for link 'link_name' in job 'foo' in instance group 'job_name'. Please provide these keys in the release only./)
      end

      it 'should throw an error when "type" key is provided' do
        link_config = {'type'=>'type', 'from'=>'link_name'}

        expect { job.add_link_from_manifest('job_name', 'consumes', 'link_name', link_config) }.to raise_error(/Cannot specify 'name' or 'type' properties in the manifest for link 'link_name' in job 'foo' in instance group 'job_name'. Please provide these keys in the release only./)
      end

      it 'should throw an error when "name" key is provided in a provides' do
        link_config = {'name' => 'link_name'}

        expect { job.add_link_from_manifest('job_name', 'provides', 'link_name', link_config) }.to raise_error(/Cannot specify 'name' or 'type' properties in the manifest for link 'link_name' in job 'foo' in instance group 'job_name'. Please provide these keys in the release only./)
      end

      it 'should throw an error when "type" key is provided in a provides' do
        link_config = {'type'=>'type'}

        expect { job.add_link_from_manifest('job_name', 'provides', 'link_name', link_config) }.to raise_error(/Cannot specify 'name' or 'type' properties in the manifest for link 'link_name' in job 'foo' in instance group 'job_name'. Please provide these keys in the release only./)
      end

      it 'should not throw an error when neither "name" or type" key is provided' do
        link_config = {'from'=>'link_name'}

        expect { job.add_link_from_manifest('job_name', 'consumes', 'link_name', link_config) }.to_not raise_error
      end
    end
  end

  describe '#bind_properties' do
    subject(:job) { described_class.new(release_version, 'foo') }

    let(:release_version) { instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion') }
    let(:template_model) { instance_double('Bosh::Director::Models::Template') }

    let (:release_job_spec_prop) do
      {
        'cc_url' => {
          'description' => 'some desc',
          'default' => 'cloudfoundry.com'
        },
        'deep_property.dont_override' => {
          'description' => 'I have no default',
        },
        'dea_max_memory' => {
          'description' => 'max memory',
          'default' => 2048
        },
      }
    end

    let (:user_defined_prop) do
      {
        'cc_url' => 'www.cc.com',
        'deep_property' => {
          'unneeded' => 'abc',
          'dont_override' => 'def'
        },
        'dea_max_memory' => 1024
      }
    end

    before do
      allow(release_version).to receive(:get_template_model_by_name).with('foo').and_return(template_model)
      allow(template_model).to receive(:properties).and_return(release_job_spec_prop)
      allow(template_model).to receive(:package_names).and_return([])
      job.add_properties(user_defined_prop, 'instance_group_name')
      job.bind_models
    end

    it 'should drop user provided properties not specified in the release job spec properties' do
      job.bind_properties('instance_group_name')

      expect(job.properties).to eq({
          'instance_group_name' =>{
          'cc_url' => 'www.cc.com',
          'deep_property' =>{
            'dont_override' => 'def'
          },
          'dea_max_memory' =>1024
        }
      })
    end

    it 'should include properties that are in the release job spec but not provided by a user' do
      user_defined_prop.delete('dea_max_memory')
      job.bind_properties('instance_group_name')

      expect(job.properties).to eq({
                                                          'instance_group_name' =>{
                                                            'cc_url' => 'www.cc.com',
                                                            'deep_property' =>{
                                                              'dont_override' => 'def'
                                                            },
                                                            'dea_max_memory' =>2048
                                                          }
                                                        })
    end

    it 'should not override user provided properties with release job spec defaults' do
      job.bind_properties('instance_group_name')
      expect(job.properties['instance_group_name']['cc_url']).to eq('www.cc.com')
    end

    context 'when user specifies invalid property type for job' do
      let(:user_defined_prop) { {'deep_property' => false} }

      it 'raises an exception explaining which property is the wrong type' do
        expect {
          job.bind_properties('instance_group_name')
        }.to raise_error Bosh::Template::InvalidPropertyType,
                         "Property 'deep_property.dont_override' expects a hash, but received 'FalseClass'"
      end
    end
  end
end
