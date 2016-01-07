require 'spec_helper'

describe Bosh::Director::DeploymentPlan::LinkPath do
  let(:logger) { Logging::Logger.new('TestLogger') }
  let(:provider_job) {
    instance_double(
        'Bosh::Director::DeploymentPlan::Job',
        {
            name: 'provider_job',
            link_infos: {
                'provider_template' => {
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
  let(:deployment) {
    instance_double(
      'Bosh::Director::DeploymentPlan::Planner',
      {
        name: 'deployment_name',
        jobs: [provider_job]
      }
    )
  }

  before do
    release_model = Bosh::Director::Models::Release.make(name: 'fake-release')
    version = Bosh::Director::Models::ReleaseVersion.make(version: '1.0.0')
    release_model.add_version(version)
    previous_deployment = Bosh::Director::Models::Deployment.make(name: 'previous_deployment', link_spec_json: '{"provider_job":{"provider_template":{"link_name":{"link_name":{"nodes":[]}}}}}')
    version.add_deployment(previous_deployment)
  end

  context 'given a link name' do
    let(:path) { {"from" => 'link_name'} }
    it 'gets full link path' do
      link_path = described_class.parse(deployment,path)
      expect(link_path.deployment).to eq('deployment_name')
      expect(link_path.job).to eq('provider_job')
      expect(link_path.template).to eq('provider_template')
      expect(link_path.name).to eq('link_name')
    end
  end

  context 'given a deployment name and a link name' do
    let(:path) { {"from" => 'deployment_name.link_name'} }
    it 'gets full link path' do
      link_path = described_class.parse(deployment,path)
      expect(link_path.deployment).to eq('deployment_name')
      expect(link_path.job).to eq('provider_job')
      expect(link_path.template).to eq('provider_template')
      expect(link_path.name).to eq('link_name')
    end
  end

  context 'given a previous deployment name and a link name' do
    let(:path) {{'from' => 'previous_deployment.link_name'}}
    it 'gets full link path' do
      link_path = described_class.parse(deployment,path)
      expect(link_path.deployment).to eq('previous_deployment')
      expect(link_path.job).to eq('provider_job')
      expect(link_path.template).to eq('provider_template')
      expect(link_path.name).to eq('link_name')
    end
  end

  context 'given a deployment that does not provide the correct link' do
    let(:path) { {"from" => 'deployment_name.unprovided_link_name'} }
    it 'should raise an exception' do
      expect{described_class.parse(deployment,path)}.to raise_error("Can't find link with name: unprovided_link_name in deployment deployment_name")
    end
  end

  context 'given a deployment that does not provide the correct link' do
    let(:path) { {"from" => 'previous_deployment.unprovided_link_name'} }
    it 'should raise an exception' do
      expect{described_class.parse(deployment,path)}.to raise_error("Can't find link with name: unprovided_link_name in deployment previous_deployment")
    end
  end

  context 'given a bad link name' do
    let(:path) { {"from" => 'unprovided_link_name'} }
    it 'should raise an exception' do
      expect{described_class.parse(deployment,path)}.to raise_error("Can't find link with name: unprovided_link_name in deployment deployment_name")
    end
  end

  context 'given no matching deployment' do
    let(:path) { {"from" => 'non_deployment.link_name'} }
    it 'should raise an exception' do
      expect{described_class.parse(deployment,path)}.to raise_error("Can't find deployment non_deployment")
    end
  end

end
