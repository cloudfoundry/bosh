require 'spec_helper'

module Bosh::Director
  module Addon
    describe Filter do
      subject(:addon_include) { Filter.parse(filter_hash, type, addon_level) }

      let(:instance_group) { instance_double(DeploymentPlan::InstanceGroup) }
      let(:addon_level) { RUNTIME_LEVEL }

      shared_examples :common_filter_checks do
        describe 'when the filter has a job with an empty job name' do
          let(:filter_hash) do
            { 'jobs' => [{ 'name' => '', 'release' => 'release_name' }] }
          end

          it 'raises' do
            expect do
              addon_include.applies?('anything', [], instance_group)
            end.to raise_error(
              AddonIncompleteFilterJobSection,
              'Job {"name"=>"", "release"=>"release_name"} in runtime '\
              "config's #{type} section must have both name and release.",
            )
          end
        end

        describe 'when the filter has a job with a missing release name' do
          let(:filter_hash) do
            { 'jobs' => [{ 'name' => 'job-name', 'release' => '' }] }
          end

          it 'raises' do
            expect do
              addon_include.applies?('anything', [], instance_group)
            end.to raise_error(
              AddonIncompleteFilterJobSection,
              'Job {"name"=>"job-name", "release"=>""} in runtime '\
              "config's #{type} section must have both name and release.",
            )
          end
        end

        describe 'when the filter has a stemcell property' do
          describe 'when the stemcell property has an os missing a name' do
            let(:filter_hash) do
              { 'stemcell' => [{ 'os' => '' }] }
            end

            it 'raises' do
              expect do
                addon_include.applies?('anything', [], instance_group)
              end.to raise_error AddonIncompleteFilterStemcellSection,
                                 "Stemcell {\"os\"=>\"\"} in runtime config's #{type} section must have an os name."
            end
          end

          describe 'when the stemcell os matches the instance group stemcell os' do
            let(:filter_hash) do
              { 'stemcell' => [{ 'os' => 'my_os' }] }
            end

            it 'applies' do
              allow(instance_group).to receive(:has_os?).with('my_os').and_return(true)
              expect(addon_include.applies?('anything', [], instance_group)).to be(true)
            end
          end

          describe 'when the stemcell os does not match the instance group stemcell os' do
            let(:filter_hash) do
              { 'stemcell' => [{ 'os' => 'my_os' }] }
            end

            it 'does not apply' do
              allow(instance_group).to receive(:has_os?).with('my_os').and_return(false)
              expect(addon_include.applies?('anything', [], instance_group)).to be(false)
            end
          end
        end

        describe 'when the filter spec has only a deployments section' do
          let(:filter_hash) do
            { 'deployments' => %w[deployment_1 deployment_2] }
          end

          describe 'when the deployment name matches one from the include spec' do
            it 'applies' do
              expect(addon_include.applies?('deployment_1', [], nil)).to be(true)
            end
          end

          describe 'when the deployment name does not match one from the filter spec' do
            it 'does not apply' do
              expect(addon_include.applies?('deployment_blarg', [], nil)).to be(false)
            end
          end
        end

        describe 'when the filter spec has only a teams section' do
          let(:filter_hash) do
            { 'teams' => %w[team_1 team_2] }
          end

          describe 'when one of the teams matches one from the included spec' do
            it 'applies' do
              expect(addon_include.applies?('anything', ['team_1'], nil)).to be(true)
            end
          end

          describe 'when none of the teams match the filter spec' do
            let(:filter_hash) do
              { 'teams' => %w[team_1 team_2] }
            end
            it 'does not apply' do
              expect(addon_include.applies?('anything', ['team_5'], nil)).to be(false)
            end
          end
        end

        describe 'when the filter spec has only a networks section' do
          let(:filter_hash) do
            { 'networks' => %w[net_1 net_2] }
          end

          describe 'when the network name matches one from the include spec' do
            it 'applies' do
              allow(instance_group).to receive(:network_present?).with('net_1').and_return(true)
              expect(addon_include.applies?('anything', [], instance_group)).to be(true)
            end
          end

          describe 'when the network name does not match any from the filter spec' do
            it 'does not apply' do
              allow(instance_group).to receive(:network_present?).with('net_1').and_return(false)
              allow(instance_group).to receive(:network_present?).with('net_2').and_return(false)
              expect(addon_include.applies?('anything', [], instance_group)).to be(false)
            end
          end
        end

        describe 'when the filter spec has only a lifecycle section' do
          let(:filter_hash) do
            { 'lifecycle' => 'errand' }
          end

          describe 'when the lifecycle type matches the one from the include spec' do
            it 'applies' do
              allow(instance_group).to receive(:lifecycle).and_return('errand')
              expect(addon_include.applies?('anything', [], instance_group)).to be(true)
            end
          end

          describe 'when the lifecycle type does not match the one from the include spec' do
            it 'does not apply' do
              allow(instance_group).to receive(:lifecycle).and_return('service')
              expect(addon_include.applies?('anything', [], instance_group)).to be(false)
            end
          end
        end

        describe 'when the filter spec has only a jobs section' do
          let(:filter_hash) do
            { 'jobs' => [{ 'name' => 'job_name', 'release' => 'release_name' }] }
          end

          describe 'when the instance group contains a matching job from the include spec' do
            it 'applies' do
              allow(instance_group).to receive(:has_job?).with('job_name', 'release_name').and_return(true)
              expect(addon_include.applies?('', [], instance_group)).to be(true)
            end
          end

          describe 'when the instance group does not contain a matching job from the filter spec' do
            it 'does not apply' do
              allow(instance_group).to receive(:has_job?).with('job_name', 'release_name').and_return(false)
              expect(addon_include.applies?('', [], instance_group)).to be(false)
            end
          end

          describe 'when there are multiple jobs on the filter spec' do
            let(:filter_hash) do
              {
                'jobs' => [
                  { 'name' => 'job_name', 'release' => 'release_name' },
                  { 'name' => 'job_name_2', 'release' => 'release_name_2' },
                ],
              }
            end

            describe 'when the instance group has all of the jobs' do
              it 'applies' do
                allow(instance_group).to receive(:has_job?).with('job_name', 'release_name').and_return(true)
                allow(instance_group).to receive(:has_job?).with('job_name_2', 'release_name_2').and_return(true)
                expect(addon_include.applies?('', [], instance_group)).to be(true)
              end
            end

            describe 'when the instance group has some of the jobs' do
              it 'applies' do
                allow(instance_group).to receive(:has_job?).with('job_name', 'release_name').and_return(true)
                allow(instance_group).to receive(:has_job?).with('job_name_2', 'release_name_2').and_return(false)
                expect(addon_include.applies?('', [], instance_group)).to be(true)
              end
            end

            describe 'when the instance group does not have any of the jobs' do
              it 'does not apply' do
                allow(instance_group).to receive(:has_job?).with('job_name', 'release_name').and_return(false)
                allow(instance_group).to receive(:has_job?).with('job_name_2', 'release_name_2').and_return(false)
                expect(addon_include.applies?('', [], instance_group)).to be(false)
              end
            end
          end
        end

        describe 'when the filter spec has both deployment section and jobs section' do
          let(:filter_hash) do
            {
              'deployments' => %w[deployment_1 deployment_2],
              'jobs' => [
                { 'name' => 'job_name', 'release' => 'release_name' },
                { 'name' => 'job_name_2', 'release' => 'release_name_2' },
              ],
            }
          end

          describe 'when the deployment name matches and the instance group contains the job' do
            it 'applies' do
              expect(instance_group).to receive(:has_job?).with('job_name', 'release_name').and_return(true)
              expect(addon_include.applies?('deployment_2', [], instance_group)).to be(true)
            end
          end

          describe 'when the deployment name does not match and the instance group contains job' do
            it 'does not apply' do
              allow(instance_group).to receive(:has_job?).with('job_name', 'release_name').and_return(true)
              expect(addon_include.applies?('deployment_3', [], instance_group)).to be(false)
            end
          end

          describe 'when the deployment name matches and the instance group contains none of the jobs' do
            it 'does not apply' do
              expect(instance_group).to receive(:has_job?).with('job_name', 'release_name').and_return(false)
              expect(instance_group).to receive(:has_job?).with('job_name_2', 'release_name_2').and_return(false)
              expect(addon_include.applies?('deployment_1', [], instance_group)).to be(false)
            end
          end
        end

        describe 'when the filter spec has both instance groups section and a jobs section' do
          let(:filter_hash) do
            {
              'instance_groups' => ['ig-1'],
              'jobs' => [
                { 'name' => 'job_name', 'release' => 'release_name' },
              ],
            }
          end

          describe 'when the instance group name matches and it contains the job' do
            it 'applies' do
              allow(instance_group).to receive(:name).and_return('ig-1')
              allow(instance_group).to receive(:has_job?).with('job_name', 'release_name').and_return(true)
              expect(addon_include.applies?('deployment_whatever', [], instance_group)).to be(true)
            end
          end

          describe 'when the instance group name does not match but the instance group contains the job' do
            it 'does not apply' do
              allow(instance_group).to receive(:name).and_return('ig-2')
              allow(instance_group).to receive(:has_job?).with('job_name', 'release_name').and_return(true)
              expect(addon_include.applies?('deployment_whatever', [], instance_group)).to be(false)
            end
          end

          describe 'when the instance group name does not match and the instance group does not contain the jobs' do
            it 'does not apply' do
              allow(instance_group).to receive(:name).and_return('ig-2')
              allow(instance_group).to receive(:has_job?).with('job_name', 'release_name').and_return(false)
              expect(addon_include.applies?('deployment_whatever', [], instance_group)).to be(false)
            end
          end
        end

        describe 'when the filter spec has deployments, instance groups and jobs sections' do
          let(:filter_hash) do
            {
              'deployments' => %w[deployment_1 deployment_2],
              'instance_groups' => ['ig-1'],
              'jobs' => [
                { 'name' => 'job_name', 'release' => 'release_name' },
              ],
            }
          end

          before do
            allow(instance_group).to receive(:has_job?).with('job_name_2', 'release_name_2').and_return(true)
          end

          describe 'when the deployment and instance group names match and the instance group contains the job' do
            it 'applies' do
              allow(instance_group).to receive(:name).and_return('ig-1')
              allow(instance_group).to receive(:has_job?).with('job_name', 'release_name').and_return(true)
              expect(addon_include.applies?('deployment_2', [], instance_group)).to be(true)
            end
          end

          describe 'deployment name matches, instance group name does not match, but instance group does not contain the jobs' do
            it 'does not apply' do
              allow(instance_group).to receive(:name).and_return('ig-2')
              allow(instance_group).to receive(:has_job?).with('job_name', 'release_name').and_return(false)
              expect(addon_include.applies?('deployment_1', [], instance_group)).to be(false)
            end
          end

          describe 'deployment name matches, instance group name does match, but instance group does not contain the jobs' do
            it 'does not apply' do
              allow(instance_group).to receive(:name).and_return('ig-1')
              allow(instance_group).to receive(:has_job?).with('job_name', 'release_name').and_return(false)
              expect(addon_include.applies?('deployment_1', [], instance_group)).to be(false)
            end
          end

          describe 'deployment name matches, instance group name does not match, but instance group does not contain the jobs' do
            it 'does not apply' do
              allow(instance_group).to receive(:name).and_return('ig-2')
              allow(instance_group).to receive(:has_job?).with('job_name', 'release_name').and_return(false)
              expect(addon_include.applies?('deployment_1', [], instance_group)).to be(false)
            end
          end

          describe 'deployment name does not match, instance group name does match, and instance group contains the jobs' do
            it 'does not apply' do
              allow(instance_group).to receive(:name).and_return('ig-1')
              allow(instance_group).to receive(:has_job?).with('job_name', 'release_name').and_return(true)
              expect(addon_include.applies?('deployment_3', [], instance_group)).to be(false)
            end
          end

          describe 'deployment name does not match, instance group name does not match, and instance group contains the jobs' do
            it 'does not apply' do
              allow(instance_group).to receive(:name).and_return('ig-2')
              allow(instance_group).to receive(:has_job?).with('job_name', 'release_name').and_return(true)
              expect(addon_include.applies?('deployment_3', [], instance_group)).to be(false)
            end
          end

          describe 'deployment name does not match, instance group name matches, but instance group does not contain the jobs' do
            it 'does not apply' do
              allow(instance_group).to receive(:name).and_return('ig-1')
              allow(instance_group).to receive(:has_job?).with('job_name', 'release_name').and_return(false)
              expect(addon_include.applies?('deployment_blarg', [], instance_group)).to be(false)
            end
          end

          describe 'none of instance group, deployment name, or jobs match' do
            it 'does not apply' do
              allow(instance_group).to receive(:name).and_return('ig-2')
              allow(instance_group).to receive(:has_job?).with('job_name', 'release_name').and_return(false)
              expect(addon_include.applies?('deployment_blarg', [], instance_group)).to be(false)
            end
          end
        end

        describe 'when the filter spec has only a instance groups section' do
          let(:filter_hash) do
            { 'instance_groups' => ['instance_group_name'] }
          end

          describe 'when the instance group has a name matching the include spec' do
            it 'applies' do
              allow(instance_group).to receive(:name).and_return('instance_group_name')
              expect(addon_include.applies?('', [], instance_group)).to be(true)
            end
          end

          describe 'when the instance group does not have a name matching the filter spec' do
            it 'does not apply' do
              allow(instance_group).to receive(:name).and_return('some_other_name')
              expect(addon_include.applies?('', [], instance_group)).to be(false)
            end
          end
        end

        describe 'when the filter spec has both deployment section and instance groups section' do
          let(:filter_hash) do
            {
              'deployments' => %w[deployment_1 deployment_2],
              'instance_groups' => ['instance_group_name'],
            }
          end

          describe 'when the deployment name matches and the instance group name matches' do
            it 'applies' do
              allow(instance_group).to receive(:name).and_return('instance_group_name')
              expect(addon_include.applies?('deployment_2', [], instance_group)).to be(true)
            end
          end

          describe 'when the deployment name does not match and the instance group name matches' do
            it 'does not apply' do
              allow(instance_group).to receive(:name).and_return('instance_group_name')
              expect(addon_include.applies?('deployment_3', [], instance_group)).to be(false)
            end
          end

          describe 'when the deployment name matches and the instance group name does not match' do
            it 'does not apply' do
              allow(instance_group).to receive(:name).and_return('instance_group_name_bad')
              expect(addon_include.applies?('deployment_1', [], instance_group)).to be(false)
            end
          end
        end

        context 'when there is a deployment filter' do
          let(:filter_hash) do
            { 'deployments' => %w[deployment_1 deployment_2] }
          end
          context 'when addon is in deployment manifest' do
            let(:addon_level) { DEPLOYMENT_LEVEL }

            it 'raises' do
              expect do
                addon_include
              end.to raise_error AddonDeploymentFilterNotAllowed,
                                 'Deployment filter is not allowed for deployment level addons.'
            end
          end

          context 'when addon is not in deployment manifest' do
            let(:addon_level) { RUNTIME_LEVEL }

            it 'raises' do
              expect do
                addon_include
              end.not_to raise_error
            end
          end
        end
      end

      describe 'include' do
        let(:type) { :include }

        describe 'applies?' do
          describe 'when the include hash is nil' do
            let(:filter_hash) { nil }

            it 'applies' do
              expect(addon_include.applies?(nil, [], nil)).to be(true)
              expect(addon_include.applies?('anything', [], instance_group)).to be(true)
            end
          end

          context 'when the addon is in the deployment manifest' do
            context 'when the team filter is specified' do
              let(:addon_level) { DEPLOYMENT_LEVEL }
              let(:filter_hash) do
                { 'teams' => ['team_5'] }
              end

              it 'does not consider' do
                expect(addon_include.applies?('anything', ['team_3'], instance_group)).to be(true)
              end
            end
          end

          context 'when the azs filter is specified' do
            let(:filter_hash) do
              { 'azs' => ['z5'] }
            end

            context 'in the deployment manifest' do
              let(:addon_level) { DEPLOYMENT_LEVEL }

              it 'applies' do
                allow(instance_group).to receive(:has_availability_zone?).with('z5').and_return(true)
                expect(addon_include.applies?('anything', [], instance_group)).to be(true)
              end
            end

            context 'in the runtime config' do
              let(:addon_level) { RUNTIME_LEVEL }

              it 'applies' do
                allow(instance_group).to receive(:has_availability_zone?).with('z5').and_return(true)
                expect(addon_include.applies?('anything', [], instance_group)).to be(true)
              end
            end
          end

          it_behaves_like :common_filter_checks
        end
      end

      describe 'exclude' do
        let(:type) { :exclude }

        let(:addon_exclude) { addon_include }
        describe 'applies?' do
          describe 'when the exclude hash is nil' do
            let(:filter_hash) { nil }

            it 'does not apply' do
              expect(addon_exclude.applies?(nil, [], nil)).to be(false)
              expect(addon_exclude.applies?('anything', [], instance_group)).to be(false)
            end
          end

          context 'when the addon is in the deployment manifest' do
            context 'when the team filter is specified' do
              let(:addon_level) { DEPLOYMENT_LEVEL }
              let(:filter_hash) do
                { 'teams' => ['team_3'] }
              end

              it 'does not consider' do
                expect(addon_exclude.applies?('anything', ['team_3'], instance_group)).to be(false)
              end
            end
          end

          context 'when the azs filter is specified' do
            let(:filter_hash) do
              { 'azs' => ['z1'] }
            end

            context 'in the deployment manifest' do
              let(:addon_level) { DEPLOYMENT_LEVEL }

              it 'does not apply' do
                allow(instance_group).to receive(:has_availability_zone?).with('z1').and_return(false)
                expect(addon_exclude.applies?('anything', [], instance_group)).to be(false)
              end
            end

            context 'in the runtime config' do
              let(:addon_level) { RUNTIME_LEVEL }

              it 'does not apply' do
                allow(instance_group).to receive(:has_availability_zone?).with('z1').and_return(false)
                expect(addon_exclude.applies?('anything', [], instance_group)).to be(false)
              end
            end
          end

          it_behaves_like :common_filter_checks
        end
      end
    end
  end
end
