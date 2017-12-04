require 'spec_helper'

describe 'links_resolver' do
  let(:deployment_name) {'fake-deployment'}
  let(:release_name) {'fake-release'}
  let(:deployment_model) {Bosh::Director::Models::Deployment.make(name: deployment_name)}

  let(:instance_group) do
    instance_group = instance_double(Bosh::Director::DeploymentPlan::InstanceGroup, {
      name: 'ig1',
      deployment_name: deployment_name,
      link_paths: []
    })
    allow(instance_group).to receive_message_chain(:persistent_disk_collection, :non_managed_disks).and_return([])
    allow(instance_group).to receive(:jobs).and_return(jobs)
    instance_group
  end


  let(:provider_job) do
    job = instance_double(Bosh::Director::DeploymentPlan::Job, name: 'j1')
    allow(job).to receive(:provided_links).and_return(provided_links)
    allow(job).to receive(:model_consumed_links).and_return([])
    job
  end

  let(:jobs) do
    [provider_job]
  end

  let(:provided_links) do
    [
      Bosh::Director::DeploymentPlan::TemplateLink.new('foo', 'pt1', false, false, 'p1')
    ]
  end

  let(:links_resolver) do
    Bosh::Director::DeploymentPlan::LinksResolver.new(deployment_plan, logger)
  end

  let(:deployment_plan) do
    deployment_plan = instance_double(Bosh::Director::DeploymentPlan::Planner, name: deployment_name, model: deployment_model)
    allow(deployment_plan).to receive(:add_link_provider)
    deployment_plan
  end

  let(:link_spec) do
    {
      'deployment_name' => deployment_name,
      'domain' => 'bosh',
      'default_network' => 'net_a',
      'networks' => ['net_a', 'net_b'],
      'instance_group' => instance_group.name,
      'instances' => [],
    }
  end

  before do
    allow(Bosh::Director::DeploymentPlan::Link).to receive_message_chain(:new, :spec).and_return(link_spec)
  end

  context 'when an instance group is updated' do
    context 'and the provided link name specified in the release did not change' do
      it 'should update the previous provider' do
        providers = Bosh::Director::Models::LinkProvider

        links_resolver.add_providers(instance_group)

        expect(providers.count).to eq(1)
        original_provider_id = providers.first.id

        links_resolver.add_providers(instance_group)

        expect(providers.count).to eq(1)
        updated_provider_id = providers.first.id

        expect(updated_provider_id).to eq(original_provider_id)
      end
    end
  end

  context 'when a job provides two different names but is aliased to the same name' do
    let(:provided_links) do
      [
        Bosh::Director::DeploymentPlan::TemplateLink.new('foo', 'pt1', false, false, 'p1'),
        Bosh::Director::DeploymentPlan::TemplateLink.new('foo', 'pt1', false, false, 'p2'),
      ]
    end

    it 'should create two providers in the database' do
      links_resolver.add_providers(instance_group)

      providers = Bosh::Director::Models::LinkProvider
      expect(providers.count).to eq(2)
    end
  end
end