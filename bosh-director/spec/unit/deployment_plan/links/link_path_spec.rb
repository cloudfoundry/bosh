require 'spec_helper'

describe Bosh::Director::DeploymentPlan::LinkPath do
  let(:logger) { Logging::Logger.new('TestLogger') }
  let(:template) {
    instance_double(
        'Bosh::Director::DeploymentPlan::Template',
        {
            name: 'provider_template',
            link_infos: {
              'provider_job' => {
                'provides' => {
                  'link_name' => {
                      'name' => 'link_name',
                      'type' => 'link_type'
                  }
                }
              }
            }
        }
    )
  }
  let(:provider_job) {
    instance_double(
        'Bosh::Director::DeploymentPlan::Job',
        {
            name: 'provider_job',
            templates: [template]
        }
    )
  }
  let(:deployment) {
    instance_double(
      'Bosh::Director::DeploymentPlan::Planner',
      {
        name: 'deployment_name',
        jobs: [provider_job]
      }
    )
  }

  let(:link_path) {described_class.new(deployment, 'consumer_job', 'consumer_job_template')}

  before do
    release_model = Bosh::Director::Models::Release.make(name: 'fake-release')
    version = Bosh::Director::Models::ReleaseVersion.make(version: '1.0.0')
    release_model.add_version(version)
    previous_deployment = Bosh::Director::Models::Deployment.make(name: 'previous_deployment', link_spec_json: '{"provider_job":{"provider_template":{"link_name":{"link_name":{"instances":[]}}}}}')
    version.add_deployment(previous_deployment)
  end

  context 'given a link name' do
    let(:path) { {"from" => 'link_name'} }
    it 'gets full link path' do
      link_path.parse(path)
      expect(link_path.deployment).to eq('deployment_name')
      expect(link_path.job).to eq('provider_job')
      expect(link_path.template).to eq('provider_template')
      expect(link_path.name).to eq('link_name')
    end

    context 'when the link is optional and path is provided' do
      let(:path) { {"from" => 'link_name', "optional" => true} }
      it 'also gets full link path' do
        link_path.parse(path)
        expect(link_path.deployment).to eq('deployment_name')
        expect(link_path.job).to eq('provider_job')
        expect(link_path.template).to eq('provider_template')
        expect(link_path.name).to eq('link_name')
      end
    end
  end

  context 'given a deployment name and a link name' do
    let(:path) { {"from" => 'link_name', "deployment" => "deployment_name"} }
    it 'gets full link path' do
      link_path.parse(path)
      expect(link_path.deployment).to eq('deployment_name')
      expect(link_path.job).to eq('provider_job')
      expect(link_path.template).to eq('provider_template')
      expect(link_path.name).to eq('link_name')
    end

    context 'when the link is optional and path is provided' do
      let(:path) { {"from" => 'link_name', "deployment" => "deployment_name", "optional" => true} }
      it 'also gets full link path' do
        link_path.parse(path)
        expect(link_path.deployment).to eq('deployment_name')
        expect(link_path.job).to eq('provider_job')
        expect(link_path.template).to eq('provider_template')
        expect(link_path.name).to eq('link_name')
      end
    end
  end

  context 'given a previous deployment name and a link name' do
    let(:path) {{'from' => 'link_name', "deployment"=>"previous_deployment"}}
    it 'gets full link path' do
      link_path.parse(path)
      expect(link_path.deployment).to eq('previous_deployment')
      expect(link_path.job).to eq('provider_job')
      expect(link_path.template).to eq('provider_template')
      expect(link_path.name).to eq('link_name')
    end

    context 'when the link is optional and path is provided' do
      let(:path) {{'from' => 'link_name', "deployment" => "previous_deployment", "optional" => true}}
      it 'also gets full link path' do
        link_path.parse(path)
        expect(link_path.deployment).to eq('previous_deployment')
        expect(link_path.job).to eq('provider_job')
        expect(link_path.template).to eq('provider_template')
        expect(link_path.name).to eq('link_name')
      end
    end

  end

  context 'when consumes block does not have from key, but the spec has a valid link type' do
    let(:path) { {"name" => "link_name", "type" => "link_type"} }
    it 'should attempt to implicitly fulfill the link' do
      link_path.parse(path)
      expect(link_path.deployment).to eq('deployment_name')
      expect(link_path.job).to eq('provider_job')
      expect(link_path.template).to eq('provider_template')
      expect(link_path.name).to eq('link_name')
    end

    context 'when the link is optional and path is provided' do
      let(:path) { {"name" => "link_name", "type" => "link_type", "optional" => true} }
      it 'also gets full link path' do
        link_path.parse(path)
        expect(link_path.deployment).to eq('deployment_name')
        expect(link_path.job).to eq('provider_job')
        expect(link_path.template).to eq('provider_template')
        expect(link_path.name).to eq('link_name')
      end
    end
  end

  context 'when consumes block does not have from key, and a manual configuration for link' do

    context 'the configuration is valid' do
      let(:link_info) { {"name" => "link_name", "properties"=>"yay", "instances"=>"yay" }}
      it 'should not parse the link and set the manual_config property' do
        link_path.parse(link_info)
        expect(link_path.deployment).to be_nil
        expect(link_path.job).to be_nil
        expect(link_path.template).to be_nil
        expect(link_path.name).to be_nil
        expect(link_path.manual_spec).to eq({"properties"=>"yay", "instances"=>"yay"})
      end
    end
  end

  context 'when consumes block does not have from key, and an invalid link type' do
    let(:path) { {"name" => "link_name", "type" => "invalid_type"} }
    it 'should throw an error' do
      expect{link_path.parse(path)}.to raise_error("Can't find link with type 'invalid_type' for job 'consumer_job' in deployment 'deployment_name'")
    end

    context 'when the link is optional' do
      let(:path) { {"name" => "link_name", "type" => "invalid_type", "optional" => true} }
      it "should not throw an error because 'from' was not explicitly stated" do
        expect{link_path.parse(path)}.to_not raise_error
      end
    end
  end

  context 'given a deployment that does not provide the correct link' do
    let(:path) { {"from" => 'unprovided_link_name', "deployment" => "deployment_name"} }
    it 'should raise an exception' do
      expect{link_path.parse(path)}.to raise_error("Can't resolve link 'unprovided_link_name' in instance group 'consumer_job' on job 'consumer_job_template' in deployment 'deployment_name'.")
    end

    context "when link is optional and the 'from' is explicitly set" do
      let(:path) { {"from" => 'unprovided_link_name', "deployment" => "deployment_name", "optional" => true} }
      it 'should throw an error' do
        expect{link_path.parse(path)}.to raise_error("Can't resolve link 'unprovided_link_name' in instance group 'consumer_job' on job 'consumer_job_template' in deployment 'deployment_name'.")
      end
    end
  end

  context 'given a different deployment that does not provide the correct link' do
    let(:path) { {"from" => 'unprovided_link_name', "deployment" => "previous_deployment"} }
    it 'should raise an exception' do
      expect{link_path.parse(path)}.to raise_error("Can't resolve link 'unprovided_link_name' in instance group 'consumer_job' on job 'consumer_job_template' in deployment 'deployment_name'. Please make sure the link was provided and shared.")
    end

    context "when link is optional and 'from' is explicitly set" do
      let(:path) { {"from" => 'unprovided_link_name', "deployment" => "previous_deployment", "optional" => true} }
      it 'should not throw an error' do
        expect{link_path.parse(path)}.to raise_error("Can't resolve link 'unprovided_link_name' in instance group 'consumer_job' on job 'consumer_job_template' in deployment 'deployment_name'. Please make sure the link was provided and shared.")
      end
    end
  end

  context 'given a bad link name' do
    let(:path) { {"from" => 'unprovided_link_name'} }
    it 'should raise an exception' do
      expect{link_path.parse(path)}.to raise_error("Can't resolve link 'unprovided_link_name' in instance group 'consumer_job' on job 'consumer_job_template' in deployment 'deployment_name'.")
    end

    context 'when link is optional' do
      let(:path) { {"from" => 'unprovided_link_name', "optional" => true} }
      it 'should still throw an error because the user intent has not been met' do
        expect{link_path.parse(path)}.to raise_error("Can't resolve link 'unprovided_link_name' in instance group 'consumer_job' on job 'consumer_job_template' in deployment 'deployment_name'.")
      end
    end

  end

  context 'given no matching deployment' do
    let(:path) { {"from" => 'link_name', "deployment" => "non_deployment"} }
    it 'should raise an exception' do
      expect{link_path.parse(path)}.to raise_error("Can't find deployment non_deployment")
    end
    context 'when link is optional' do
      let(:path) { {"from" => 'link_name', "deployment" => "non_deployment", "optional" => true} }
      it 'should still throw an error because the user intent has not been met' do
        expect{link_path.parse(path)}.to raise_error("Can't find deployment non_deployment")
      end
    end
  end


  context 'when there are multiple links with the same type' do
    let(:path) { {"name" => 'link_name', 'type' => 'link_type'} }
    let(:additional_template) {
      instance_double(
          'Bosh::Director::DeploymentPlan::Template',
          {
              name: 'provider_template',
              link_infos: {
                  'additional_provider_job' => {
                      'provides' => {
                          'link_name' => {
                              'name' => 'link_name',
                              'type' => 'link_type'
                          }
                      }
                  }
              }
          }
      )
    }
    let(:additional_provider_job) {
      instance_double(
          'Bosh::Director::DeploymentPlan::Job',
          {
              name: 'additional_provider_job',
              templates: [additional_template]
          }
      )
    }
    let(:deployment) {
      instance_double(
          'Bosh::Director::DeploymentPlan::Planner',
          {
              name: 'deployment_name',
              jobs: [provider_job, additional_provider_job]
          }
      )
    }
    it 'should raise an exception' do
      expect{link_path.parse(path)}.to raise_error("Multiple instance groups provide links of type 'link_type'. Cannot decide which one to use for instance group 'consumer_job'.
   deployment_name.provider_job.provider_template.link_name
   deployment_name.additional_provider_job.provider_template.link_name")
    end

    context 'when link is optional' do
      let(:path) { {"name" => 'link_name', 'type' => 'link_type', 'optional' => true} }
      it 'should still throw an error' do
        expect{link_path.parse(path)}.to raise_error("Multiple instance groups provide links of type 'link_type'. Cannot decide which one to use for instance group 'consumer_job'.
   deployment_name.provider_job.provider_template.link_name
   deployment_name.additional_provider_job.provider_template.link_name")
      end
    end
  end
end
