require 'spec_helper'

describe Bosh::Director::DeploymentPlan::Template do
  # Currently this class is tested mostly in DeploymentPlan::ReleaseVersion spec.
  # In the future these tests can be migrated to here.
  describe '#add_link_from_manifest' do
    subject(:template) { described_class.new(nil, 'foo') }


    context 'given properly formated arguments' do
      before {
        template.add_link_from_manifest('job_name', 'provides', 'link_name', {'properties'=>['plant'], 'from'=>'link_name'})
      }
      it 'should populate link_infos' do
        expect(template.link_infos).to eq({"job_name"=>{"provides"=>{"link_name"=>{"properties"=>["plant"], "from"=>"link_name"}}}})
      end
    end

    context 'given incorrect manual configuration of consume link' do
      it 'should throw an error' do
        link_config = {'name'=>'link_name','type'=>'type', 'instances' => 'something', 'from'=>'link_name'}

        expect{
          template.add_link_from_manifest('job_name', 'consumes', 'link_name', link_config)
        }.to raise_error(/Cannot specify both 'instances' and 'from' keys for link 'link_name' in job 'foo' in instance group 'job_name'./)
      end

      it 'should throw an error' do
        link_config = {'name'=>'link_name','type'=>'type', 'properties' => 'something', 'from'=>'link_name'}

        expect{
          template.add_link_from_manifest('job_name', 'consumes', 'link_name', link_config)
        }.to raise_error(/Cannot specify both 'properties' and 'from' keys for link 'link_name' in job 'foo' in instance group 'job_name'.
Cannot specify 'properties' without 'instances' for link 'link_name' in job 'foo' in instance group 'job_name'./)
      end
    end

    context 'using restricted keys for links in the deployment manifest' do
      it 'should throw an error when "name" key is provided' do
        link_config = {'name'=>'link_name', 'from'=>'link_name'}

        expect { template.add_link_from_manifest('job_name', 'consumes', 'link_name', link_config) }.to raise_error(/Cannot specify 'name' or 'type' properties in the manifest for link 'link_name' in job 'foo' in instance group 'job_name'. Please provide these keys in the release only./)
      end

      it 'should throw an error when "type" key is provided' do
        link_config = {'type'=>'type', 'from'=>'link_name'}

        expect { template.add_link_from_manifest('job_name', 'consumes', 'link_name', link_config) }.to raise_error(/Cannot specify 'name' or 'type' properties in the manifest for link 'link_name' in job 'foo' in instance group 'job_name'. Please provide these keys in the release only./)
      end

      it 'should throw an error when "name" key is provided in a provides' do
        link_config = {'name' => 'link_name'}

        expect { template.add_link_from_manifest('job_name', 'provides', 'link_name', link_config) }.to raise_error(/Cannot specify 'name' or 'type' properties in the manifest for link 'link_name' in job 'foo' in instance group 'job_name'. Please provide these keys in the release only./)
      end

      it 'should throw an error when "type" key is provided in a provides' do
        link_config = {'type'=>'type'}

        expect { template.add_link_from_manifest('job_name', 'provides', 'link_name', link_config) }.to raise_error(/Cannot specify 'name' or 'type' properties in the manifest for link 'link_name' in job 'foo' in instance group 'job_name'. Please provide these keys in the release only./)
      end

      it 'should not throw an error when neither "name" or type" key is provided' do
        link_config = {'from'=>'link_name'}

        expect { template.add_link_from_manifest('job_name', 'consumes', 'link_name', link_config) }.to_not raise_error
      end
    end
  end
end
