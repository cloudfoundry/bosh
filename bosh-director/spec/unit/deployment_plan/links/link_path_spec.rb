require 'spec_helper'

describe Bosh::Director::DeploymentPlan::LinkPath do
  let(:logger) { Logging::Logger.new('TestLogger') }
  let(:path) { 'fake-deployment.fake-job.fake-template.fake-name' }

  it 'sets deployment, job, template, name' do
    link_path = described_class.parse('current-deployment', path, logger)
    expect(link_path.deployment).to eq('fake-deployment')
    expect(link_path.job).to eq('fake-job')
    expect(link_path.template).to eq('fake-template')
    expect(link_path.name).to eq('fake-name')
  end

  context 'when deployment name is not provided' do
    let(:path) { 'fake-job.fake-template.fake-name' }

    it 'sets deployment name to current deployment name' do
      link_path = described_class.parse('current-deployment', path, logger)
      expect(link_path.deployment).to eq('current-deployment')
    end
  end

  context 'when link is not in correct format' do
    let(:path) { 'invalid.path' }

    it 'raises an error' do
      expect {
        described_class.parse('current-deployment', path, logger)
      }.to raise_error Bosh::Director::DeploymentInvalidLink, "Link 'invalid.path' is invalid. " +
            "A link must have either 3 or 4 parts: [deployment_name.]job_name.template_name.link_name"
    end
  end
end
