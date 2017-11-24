require 'spec_helper'

describe 'links_resolve' do
  let(:deployment_name) {'fake-deployment'}
  let(:release_name) {'fake-release'}
  let(:deployment_model) {Bosh::Director::Models::Deployment.make(name: deployment_name)}
  let(:release) {create_new_release('1')}

  def create_new_release(version, templates = {})
    release_model = Bosh::Director::Models::Release.find_or_create(name: release_name)
    release_version = Bosh::Director::Models::ReleaseVersion.make(version: version)
    release_model.add_version(release_version)

    templates.each do |template|
      template_model = Bosh::Director::Models::Template.make(
        name: template.name,
        spec: {
          consumes: template.consumes || [],
          provides: template.provides || [],
          properties: template.properties || {},
        },
        release_id: release_model.id
      )
      release_version.add_template(template_model)
    end

    release_version
  end

  def generate_manifest(release_version = 'latest')
    manifest = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    manifest['releases'] = [
      {
        'name' => release_name,
        'version' => release_version,
      }
    ]
  end

  context 'when a job provides two different names but is aliased to the same name' do
    let(:instance_group) do
      instance_group = instance_double(Bosh::Director::DeploymentPlan::InstanceGroup, {
        name: 'ig1',
        deployment_name: deployment_name,
        link_paths: []
      })
      allow(instance_group).to receive_message_chain(:persistent_disk_collection, :non_managed_disks).and_return([])
      instance_group
    end

    let(:provider_job) do
      job = instance_double(Bosh::Director::DeploymentPlan::Job, name: 'j1')
      allow(job).to receive(:provided_links).and_return(
        [
          Bosh::Director::DeploymentPlan::TemplateLink.new('foo', 'pt1', false, false, 'p1'),
          Bosh::Director::DeploymentPlan::TemplateLink.new('foo', 'pt1', false, false, 'p2'),
        ]
      )
      allow(job).to receive(:model_consumed_links).and_return([])
      job
    end

    let(:jobs) do
      [provider_job]
    end

    let(:links_resolver) do
      Bosh::Director::DeploymentPlan::LinksResolver.new(deployment_plan, logger)
    end

    let(:deployment_plan) {instance_double(Bosh::Director::DeploymentPlan::Planner, name: deployment_name, model: deployment_model)}

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
      allow(instance_group).to receive(:jobs).and_return(jobs)
      allow(Bosh::Director::DeploymentPlan::Link).to receive_message_chain(:new, :spec).and_return(link_spec)
      allow(deployment_plan).to receive(:add_link_provider) # Maybe we can do this better. We should avoid storing more state in the deployment plan.
    end

    it 'should create two providers in the database' do
      links_resolver.resolve(instance_group)

      providers = Bosh::Director::Models::LinkProvider
      expect(providers.count).to eq(2)
    end
  end

  class Template < Struct.new(:name, :provides, :consumes, :properties)
  end
end