require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    describe LinkLookupFactory do
      let(:consumed_link) { instance_double(Bosh::Director::DeploymentPlan::TemplateLink) }
      let(:link_path) { instance_double(Bosh::Director::DeploymentPlan::LinkPath) }
      let(:deployment_plan) { instance_double(Bosh::Director::DeploymentPlan::Planner) }
      let(:link_network_options) { {} }

      describe '#create' do
        context 'when provider and consumer is from the SAME deployment' do
          before do
            allow(link_path).to receive(:deployment).and_return('dep-1')
            allow(deployment_plan).to receive(:name).and_return('dep-1')
            allow(deployment_plan).to receive(:instance_groups)
          end

          it 'returns a PlannerLinkLookup object' do
            planner_link_lookup = LinkLookupFactory.create(consumed_link, link_path, deployment_plan, link_network_options)
            expect(planner_link_lookup).to be_kind_of(PlannerLinkLookup)
          end
        end

        context 'when provider and consumer is from DIFFERENT deployment' do
          let(:provider_deployment_model) { instance_double(Bosh::Director::Models::Deployment) }

          before do
            allow(link_path).to receive(:deployment).and_return('dep-1')
            allow(deployment_plan).to receive(:name).and_return('dep-2')
            allow(Bosh::Director::Models::Deployment).to receive(:find).with({name: 'dep-1'}).and_return(provider_deployment_model)
          end

          it 'returns a DeploymentLinkSpecLookup object' do
            expect(provider_deployment_model).to receive(:link_spec).and_return({'meow' => 'cat'})

            deployment_link_lookup = LinkLookupFactory.create(consumed_link, link_path, deployment_plan, link_network_options)
            expect(deployment_link_lookup).to be_kind_of(DeploymentLinkSpecLookup)
          end

          context 'when provider deployment does not exist' do
            before do
              allow(Bosh::Director::Models::Deployment).to receive(:find).with({name: 'dep-1'}).and_return(nil)
            end

            it 'raises an error' do
              expect {
                LinkLookupFactory.create(consumed_link, link_path, deployment_plan, link_network_options)
              }.to raise_error Bosh::Director::DeploymentInvalidLink
            end
          end
        end
      end
    end

    describe PlannerLinkLookup do
      let(:consumed_link) { instance_double(Bosh::Director::DeploymentPlan::TemplateLink) }
      let(:link_path) { instance_double(Bosh::Director::DeploymentPlan::LinkPath) }
      let(:deployment_plan) { instance_double(Bosh::Director::DeploymentPlan::Planner) }
      let(:link_network_options) { {} }
      let(:instance_group) { instance_double(Bosh::Director::DeploymentPlan::InstanceGroup) }
      let(:instance_groups) { [instance_group] }
      let(:job) { instance_double(Bosh::Director::DeploymentPlan::Job) }
      let(:jobs) { [job] }

      before do
        allow(deployment_plan).to receive(:instance_groups).and_return(instance_groups)
        allow(instance_group).to receive(:name).and_return('ig_1')
        allow(link_path).to receive(:job).and_return('ig_1')
      end

      describe '#find_link_spec' do
        context 'when instance group of link path cannot be found in deployment plan' do
          before do
            allow(deployment_plan).to receive(:instance_groups).and_return([])
          end

          it 'returns nil' do
            look_up = PlannerLinkLookup.new(consumed_link, link_path, deployment_plan, link_network_options)
            expect(look_up.find_link_spec).to be_nil
          end
        end

        context 'when it is a disk link' do
          before do
            allow(link_path).to receive(:disk?).and_return(true)
            allow(link_path).to receive(:deployment).and_return('my-dep')
            allow(link_path).to receive(:name).and_return('my-disk')
          end

          it 'returns disk spec' do
            look_up = PlannerLinkLookup.new(consumed_link, link_path, deployment_plan, link_network_options)
            expect(look_up.find_link_spec).to eq({
               'deployment_name'=>'my-dep',
               'properties'=>{'name'=>'my-disk'},
               'networks'=>[],
               'instances'=>[]
            })
          end
        end

        context 'when no job has the name specified in the link' do
          before do
            allow(link_path).to receive(:disk?).and_return(false)
            allow(instance_group).to receive(:jobs).and_return([])
          end

          it 'returns nil' do
            look_up = PlannerLinkLookup.new(consumed_link, link_path, deployment_plan, link_network_options)
            expect(look_up.find_link_spec).to be_nil
          end
        end

        context 'when NO job provide a link with the same name and type of link path' do
          let(:provided_link) { instance_double(Bosh::Director::DeploymentPlan::TemplateLink) }

          before do
            allow(job).to receive(:name).and_return('job_name')
            allow(link_path).to receive(:template).and_return('job_name')
            allow(link_path).to receive(:disk?).and_return(false)
            allow(instance_group).to receive(:jobs).and_return(jobs)
            allow(job).to receive(:provided_links).with('ig_1').and_return([provided_link])
          end

          it 'returns nil if provided links are empty' do
            allow(job).to receive(:provided_links).with('ig_1').and_return([])
            look_up = PlannerLinkLookup.new(consumed_link, link_path, deployment_plan, link_network_options)
            expect(look_up.find_link_spec).to be_nil
          end

          it 'returns nil if provided link name does not match' do
            allow(provided_link).to receive(:name).and_return('my_link')
            allow(link_path).to receive(:name).and_return('my_other_link')

            look_up = PlannerLinkLookup.new(consumed_link, link_path, deployment_plan, link_network_options)
            expect(look_up.find_link_spec).to be_nil
          end

          it 'returns nil if provided link type does not match' do
            allow(provided_link).to receive(:name).and_return('my_link')
            allow(link_path).to receive(:name).and_return('my_link')

            allow(provided_link).to receive(:type).and_return('my_type')
            allow(consumed_link).to receive(:type).and_return('my_other_type')

            look_up = PlannerLinkLookup.new(consumed_link, link_path, deployment_plan, link_network_options)
            expect(look_up.find_link_spec).to be_nil
          end
        end

        context 'when a job provide a link with the same name and type of link path' do
          let(:provided_link) { instance_double(Bosh::Director::DeploymentPlan::TemplateLink) }
          let(:found_link) { instance_double(Bosh::Director::DeploymentPlan::Link) }
          let(:link_network_options) do
            {
              :preferred_network_name => 'the-network',
              :enforce_ip => true,
            }
          end

          before do
            allow(link_path).to receive(:template).and_return('job_name')
            allow(link_path).to receive(:disk?).and_return(false)
            allow(link_path).to receive(:name).and_return('my_link')
            allow(link_path).to receive(:deployment).and_return('my_dep')

            allow(instance_group).to receive(:jobs).and_return(jobs)

            allow(job).to receive(:name).and_return('job_name')
            allow(job).to receive(:provided_links).with('ig_1').and_return([provided_link])

            allow(provided_link).to receive(:name).and_return('my_link')
            allow(provided_link).to receive(:type).and_return('my_type')
            allow(consumed_link).to receive(:type).and_return('my_type')

            allow(found_link).to receive(:spec).and_return({'cat' => 'meow'})
          end

          it 'returns link spec' do
            expect(Bosh::Director::DeploymentPlan::Link).to receive(:new).with('my_dep', 'my_link', instance_group, job, link_network_options).and_return(found_link)
            look_up = PlannerLinkLookup.new(consumed_link, link_path, deployment_plan, link_network_options)
            expect(look_up.find_link_spec).to eq({'cat' => 'meow'})
          end
        end
      end
    end

    describe DeploymentLinkSpecLookup do
      # BACKFILL when doing cross deployment link ip_addresses
    end
  end
end
