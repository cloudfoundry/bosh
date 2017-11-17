require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    describe LinkPath do
      let(:logger) { Logging::Logger.new('TestLogger') }

      let(:job) do
        job = Job.new(nil, 'provider_job', deployment_name)
        job.add_link_from_release('provider_instance_group', 'provides', 'link_name', {'name' => 'link_name', 'type' => 'link_type'})
        job
      end

      let(:persistent_disk_collection) {
        collection = PersistentDiskCollection.new(logger)
        collection.add_by_disk_name_and_type('ssd-disk', DiskType.new('solid-state', 10, {}))
        collection
      }

      let(:provider_instance_group) do
        group = InstanceGroup.new(logger)
        group.name = 'provider_instance_group'
        group.jobs = [job]
        group.persistent_disk_collection = persistent_disk_collection
        group
      end

      let(:deployment_name) { 'deployment_name' }
      let(:instance_groups) { [provider_instance_group] }
      let(:link_path) do
        LinkPath.new(deployment_name, instance_groups, 'consumer_instance_group', 'consumer_instance_group_job')
      end

      let(:link_name) {'link_name'}
      let(:deployment_id) {1}
      let(:link_shared) {true}
      let(:version) { Models::ReleaseVersion.make(version: '1.0.0') }
      let(:previous_deployment) {Models::Deployment.make(name: 'previous_deployment', link_spec_json: '{"provider_instance_group":{"provider_job":{"link_name":{"link_name":{"instances":[]}}}}}')}
      before do
        release_model = Models::Release.make(name: 'fake-release')
        release_model.add_version(version)
        deployment_id = previous_deployment.id
      end

      context 'link is shared' do
        before do
          allow(Bosh::Director::Models::LinkProvider).to receive(:where).with(deployment: previous_deployment, name: link_name ).and_return(
            [Bosh::Director::Models::LinkProvider.make(
              name: 'link_name',
              shared: true,
              deployment_id: deployment_id,
              instance_group: 'provider_instance_group',
              consumable: link_shared,
              link_provider_definition_type: 'http_endpoint',
              link_provider_definition_name: 'http_endpoint',
              owner_object_name: 'provider_job',
              owner_object_type: 'Job',
              content: {
                "instances":[],
                # "instance_group": "provider_instance_group"
              }.to_json)])
          version.add_deployment(previous_deployment)

        end

        context 'given a link name' do
          let(:path) { { 'from' => 'link_name'} }
          it 'gets full link path' do
            link_path.parse(path)
            expect(link_path.deployment).to eq('deployment_name')
            expect(link_path.job).to eq('provider_instance_group')
            expect(link_path.template).to eq('provider_job')
            expect(link_path.name).to eq('link_name')
          end

          context 'when the link is optional and path is provided' do
            let(:path) { { 'from' => 'link_name', 'optional' => true} }
            it 'also gets full link path' do
              link_path.parse(path)
              expect(link_path.deployment).to eq('deployment_name')
              expect(link_path.job).to eq('provider_instance_group')
              expect(link_path.template).to eq('provider_job')
              expect(link_path.name).to eq('link_name')
            end
          end
        end

        context 'given a disk link name' do
          let(:path) { { 'from' => 'ssd-disk'} }
          it 'returns a link path' do
            link_path.parse(path)
            expect(link_path.deployment).to eq('deployment_name')
            expect(link_path.job).to eq('provider_instance_group')
            expect(link_path.template).to eq(nil) #disks are not provided by a job, they're declared on the instance group
            expect(link_path.name).to eq('ssd-disk')
          end
        end

        context 'given a deployment name and a link name' do
          let(:path) { { 'from' => 'link_name', 'deployment' => 'deployment_name' } }
          it 'gets full link path' do
            link_path.parse(path)
            expect(link_path.deployment).to eq('deployment_name')
            expect(link_path.job).to eq('provider_instance_group')
            expect(link_path.template).to eq('provider_job')
            expect(link_path.name).to eq('link_name')
          end

          context 'when the link is optional and path is provided' do
            let(:path) { { 'from' => 'link_name', 'deployment' => 'deployment_name', 'optional' => true} }
            it 'also gets full link path' do
              link_path.parse(path)
              expect(link_path.deployment).to eq('deployment_name')
              expect(link_path.job).to eq('provider_instance_group')
              expect(link_path.template).to eq('provider_job')
              expect(link_path.name).to eq('link_name')
            end
          end
        end

        context 'given a previous deployment name and a link name' do
          let(:path) {{'from' => 'link_name', 'deployment' => 'previous_deployment' }}
          it 'gets full link path' do
            link_path.parse(path)
            expect(link_path.deployment).to eq('previous_deployment')
            expect(link_path.job).to eq('provider_instance_group')
            expect(link_path.template).to eq('provider_job')
            expect(link_path.name).to eq('link_name')
          end

          context 'when the link is optional and path is provided' do
            let(:path) {{'from' => 'link_name', 'deployment' => 'previous_deployment', 'optional' => true}}
            it 'also gets full link path' do
              link_path.parse(path)
              expect(link_path.deployment).to eq('previous_deployment')
              expect(link_path.job).to eq('provider_instance_group')
              expect(link_path.template).to eq('provider_job')
              expect(link_path.name).to eq('link_name')
            end
          end
        end

        context 'when consumes block does not have from key, but the spec has a valid link type' do
          let(:path) { { 'name' => 'link_name', 'type' => 'link_type' } }
          it 'should attempt to implicitly fulfill the link' do
            link_path.parse(path)
            expect(link_path.deployment).to eq('deployment_name')
            expect(link_path.job).to eq('provider_instance_group')
            expect(link_path.template).to eq('provider_job')
            expect(link_path.name).to eq('link_name')
          end

          context 'when the link is optional and path is provided' do
            let(:path) { { 'name' => 'link_name', 'type' => 'link_type', 'optional' => true} }
            it 'also gets full link path' do
              link_path.parse(path)
              expect(link_path.deployment).to eq('deployment_name')
              expect(link_path.job).to eq('provider_instance_group')
              expect(link_path.template).to eq('provider_job')
              expect(link_path.name).to eq('link_name')
            end
          end
        end

        context 'when consumes block does not have from key, and a manual configuration for link' do
          context 'the configuration is valid' do
            let(:link_info) do
              {
                'name' => 'link_name',
                'properties' => 'yay',
                'instances' => 'yay',
                'address' => 'find-me-here',
              }
            end
            it 'should not parse the link and set the manual_config property' do
              link_path.parse(link_info)
              expect(link_path.deployment).to be_nil
              expect(link_path.job).to be_nil
              expect(link_path.template).to be_nil
              expect(link_path.name).to be_nil
              expect(link_path.manual_spec).to eq(
                                                 {
                                                   'deployment_name' => 'deployment_name',
                                                   'properties' => 'yay',
                                                   'instances' => 'yay',
                                                   'address' => 'find-me-here',
                                                 }
                                               )
            end
          end
        end

        context 'when consumes block does not have from key, and an invalid link type' do
          let(:path) { { 'name' => 'link_name', 'type' => 'invalid_type' } }
          it 'should throw an error' do
            expect{link_path.parse(path)}.to raise_error("Can't find link with type 'invalid_type' for job 'consumer_instance_group' in deployment 'deployment_name'")
          end

          context 'when the link is optional' do
            let(:path) { { 'name' => 'link_name', 'type' => 'invalid_type', 'optional' => true} }
            it "should not throw an error because 'from' was not explicitly stated" do
              expect{link_path.parse(path)}.to_not raise_error
            end
          end
        end

        context 'given a deployment that does not provide the correct link' do
          let(:path) { { 'from' => 'unprovided_link_name', 'deployment' => 'deployment_name' } }
          it 'should raise an exception' do
            expect{link_path.parse(path)}.to raise_error("Can't resolve link 'unprovided_link_name' in instance group 'consumer_instance_group' on job 'consumer_instance_group_job' in deployment 'deployment_name'.")
          end

          context "when link is optional and the 'from' is explicitly set" do
            let(:path) { { 'from' => 'unprovided_link_name', 'deployment' => 'deployment_name', 'optional' => true} }
            it 'should throw an error' do
              expect{link_path.parse(path)}.to raise_error("Can't resolve link 'unprovided_link_name' in instance group 'consumer_instance_group' on job 'consumer_instance_group_job' in deployment 'deployment_name'.")
            end
          end
        end

        context 'given a different deployment that does not provide the correct link' do
          let(:path) { { 'from' => 'unprovided_link_name', 'deployment' => 'previous_deployment' } }
          link_name = "unprovided_link_name"
          before do
            allow(Bosh::Director::Models::LinkProvider).to receive(:where).with(deployment: previous_deployment, name: link_name ).and_return([])
          end
          it 'should raise an exception' do
            expect{link_path.parse(path)}.to raise_error("Can't resolve link '#{link_name}' in instance group 'consumer_instance_group' on job 'consumer_instance_group_job' in deployment 'deployment_name'. Please make sure the link was provided and shared.")
          end

          context "when link is optional and 'from' is explicitly set" do
            let(:path) { { 'from' => link_name, 'deployment' => 'previous_deployment', 'optional' => true} }
            it 'should not throw an error' do
              expect{link_path.parse(path)}.to raise_error("Can't resolve link '#{link_name}' in instance group 'consumer_instance_group' on job 'consumer_instance_group_job' in deployment 'deployment_name'. Please make sure the link was provided and shared.")
            end
          end
        end

        context 'given a bad link name' do
          let(:path) { { 'from' => 'unprovided_link_name'} }
          it 'should raise an exception' do
            expect{link_path.parse(path)}.to raise_error("Can't resolve link 'unprovided_link_name' in instance group 'consumer_instance_group' on job 'consumer_instance_group_job' in deployment 'deployment_name'.")
          end

          context 'when link is optional' do
            let(:path) { { 'from' => 'unprovided_link_name', 'optional' => true} }
            it 'should still throw an error because the user intent has not been met' do
              expect{link_path.parse(path)}.to raise_error("Can't resolve link 'unprovided_link_name' in instance group 'consumer_instance_group' on job 'consumer_instance_group_job' in deployment 'deployment_name'.")
            end
          end

        end

        context 'given no matching deployment' do
          let(:path) { { 'from' => 'link_name', 'deployment' => 'non_deployment' } }
          it 'should raise an exception' do
            expect{link_path.parse(path)}.to raise_error("Can't find deployment non_deployment")
          end
          context 'when link is optional' do
            let(:path) { { 'from' => 'link_name', 'deployment' => 'non_deployment', 'optional' => true} }
            it 'should still throw an error because the user intent has not been met' do
              expect{link_path.parse(path)}.to raise_error("Can't find deployment non_deployment")
            end
          end
        end

        context 'when there are multiple links with the same type' do
          let(:path) { { 'name' => 'link_name', 'type' => 'link_type'} }
          let(:additional_job) do
            job = Job.new(nil, 'provider_job', deployment_name)
            job.add_link_from_release('additional_provider_instance_group', 'provides', 'link_name', {'name' => 'link_name', 'type' => 'link_type'})
            job
          end
          let(:additional_provider_instance_group) do
            group = InstanceGroup.new(logger)
            group.name = 'additional_provider_instance_group'
            group.jobs = [additional_job]
            group
          end
          let(:instance_groups) { [provider_instance_group, additional_provider_instance_group] }

          it 'should raise an exception' do
            expect{link_path.parse(path)}.to raise_error("Multiple instance groups provide links of type 'link_type'. Cannot decide which one to use for instance group 'consumer_instance_group'.
   deployment_name.provider_instance_group.provider_job.link_name
   deployment_name.additional_provider_instance_group.provider_job.link_name")
          end

          context 'when link is optional' do
            let(:path) { { 'name' => 'link_name', 'type' => 'link_type', 'optional' => true} }
            it 'should still throw an error' do
              expect{link_path.parse(path)}.to raise_error("Multiple instance groups provide links of type 'link_type'. Cannot decide which one to use for instance group 'consumer_instance_group'.
   deployment_name.provider_instance_group.provider_job.link_name
   deployment_name.additional_provider_instance_group.provider_job.link_name")
            end
          end
        end
      end

      context 'link is not shared' do
        let(:link_shared) {false}
        before do
          allow(Bosh::Director::Models::LinkProvider).to receive(:where).with(deployment: previous_deployment, name: link_name ).and_return(
            [Bosh::Director::Models::LinkProvider.make(
              name: 'link_name',
              shared: link_shared,
              deployment_id: deployment_id,
              instance_group: 'provider_instance_group',
              consumable: true,
              link_provider_definition_type: 'http_endpoint',
              link_provider_definition_name: 'http_endpoint',
              owner_object_name: 'provider_job',
              owner_object_type: 'Job',
              content: {
                "instances":[],
                "instance_group": "provider_instance_group"
              }.to_json)])
          version.add_deployment(previous_deployment)

        end

        context 'given a different deployment' do
          let(:link_name) { "link_name" }
          let(:path) { { 'from' => link_name, 'deployment' => 'previous_deployment' } }
          it 'should raise an exception' do
            expect{link_path.parse(path)}.to raise_error("Can't resolve link '#{link_name}' in instance group 'consumer_instance_group' on job 'consumer_instance_group_job' in deployment 'deployment_name'. Please make sure the link was provided and shared.")
          end

          context "when link is optional and 'from' is explicitly set" do
            let(:path) { { 'from' => link_name, 'deployment' => 'previous_deployment', 'optional' => true} }
            it 'should throw an error' do
              expect{link_path.parse(path)}.to raise_error("Can't resolve link '#{link_name}' in instance group 'consumer_instance_group' on job 'consumer_instance_group_job' in deployment 'deployment_name'. Please make sure the link was provided and shared.")
            end
          end
        end
      end
    end
  end
end
