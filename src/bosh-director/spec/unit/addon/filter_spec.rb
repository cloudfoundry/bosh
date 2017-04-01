require 'spec_helper'

module Bosh::Director
  module Addon
    describe Filter do
      subject(:addon_include) { Filter.parse(filter_hash, type, addon_level) }
      let(:instance_group) { instance_double(DeploymentPlan::InstanceGroup) }
      let(:addon_level) { RUNTIME_LEVEL }

      shared_examples :common_filter_checks do
        describe 'when the filter has a job with an empty job name' do
          let(:filter_hash) { {'jobs' => [{'name' => '', 'release' => 'release_name'}]} }

          it 'raises' do
            expect {
              addon_include.applies?('anything', instance_group)
            }.to raise_error AddonIncompleteFilterJobSection,
              "Job {\"name\"=>\"\", \"release\"=>\"release_name\"} in runtime config's #{type} section must have both name and release."
          end
        end

        describe 'when the filter has a job with a missing release name' do
          let(:filter_hash) { {'jobs' => [{'name' => 'job-name', 'release' => ''}]} }

          it 'raises' do
            expect {
              addon_include.applies?('anything', instance_group)
            }.to raise_error AddonIncompleteFilterJobSection,
              "Job {\"name\"=>\"job-name\", \"release\"=>\"\"} in runtime config's #{type} section must have both name and release."
          end
        end

        describe 'when the filter has a stemcell property' do
          describe 'when the stemcell property has an os missing a name' do
            let(:filter_hash) { {'stemcell' => [{'os' => ''}]} }

            it 'raises' do
              expect {
                addon_include.applies?('anything', instance_group)
              }.to raise_error AddonIncompleteFilterStemcellSection,
                "Stemcell {\"os\"=>\"\"} in runtime config's #{type} section must have an os name."
            end
          end

          describe 'when the stemcell os matches the instance group stemcell os' do
            let(:filter_hash) { {'stemcell' => [{'os' => 'my_os'}]} }

            it 'applies' do
              allow(instance_group).to receive(:has_os?).with('my_os').and_return(true)
              expect(addon_include.applies?('anything', instance_group)).to be(true)
            end
          end

          describe 'when the stemcell os does not match the instance group stemcell os' do
            let(:filter_hash) { {'stemcell' => [{'os' => 'my_os'}]} }

            it 'does not apply' do
              allow(instance_group).to receive(:has_os?).with('my_os').and_return(false)
              expect(addon_include.applies?('anything', instance_group)).to be(false)
            end
          end
        end

        describe 'when the filter spec has only a deployments section' do
          let(:filter_hash) { {'deployments' => ['deployment_1', 'deployment_2']} }

          describe 'when the deployment name matches one from the include spec' do
            it 'applies' do
              expect(addon_include.applies?('deployment_1', nil)).to be(true)
            end
          end

          describe 'when the deployment name does not match one from the filter spec' do
            it 'does not apply' do
              expect(addon_include.applies?('deployment_blarg', nil)).to be(false)
            end
          end
        end

        describe 'when the filter spec has only a jobs section' do
          let(:filter_hash) { {'jobs' => [{'name' => 'job_name', 'release' => 'release_name'}]} }

          describe 'when the instance group contains a matching job from the include spec' do
            it 'applies' do
              allow(instance_group).to receive(:has_job?).with('job_name', 'release_name').and_return(true)
              expect(addon_include.applies?('', instance_group)).to be(true)
            end
          end

          describe 'when the instance group does not contain a matching job from the filter spec' do
            it 'does not apply' do
              allow(instance_group).to receive(:has_job?).with('job_name', 'release_name').and_return(false)
              expect(addon_include.applies?('', instance_group)).to be(false)
            end
          end

          describe 'when there are multiple jobs on the filter spec' do
            let(:filter_hash) {
              {
                'jobs' => [
                  {'name' => 'job_name', 'release' => 'release_name'},
                  {'name' => 'job_name_2', 'release' => 'release_name_2'}
                ]
              }
            }

            describe 'when the instance group has all of the jobs' do
              it 'applies' do
                allow(instance_group).to receive(:has_job?).with('job_name', 'release_name').and_return(true)
                allow(instance_group).to receive(:has_job?).with('job_name_2', 'release_name_2').and_return(true)
                expect(addon_include.applies?('', instance_group)).to be(true)
              end
            end

            describe 'when the instance group has some of the jobs' do
              it 'applies' do
                allow(instance_group).to receive(:has_job?).with('job_name', 'release_name').and_return(true)
                allow(instance_group).to receive(:has_job?).with('job_name_2', 'release_name_2').and_return(false)
                expect(addon_include.applies?('', instance_group)).to be(true)
              end
            end

            describe 'when the instance group does not have any of the jobs' do
              it 'does not apply' do
                allow(instance_group).to receive(:has_job?).with('job_name', 'release_name').and_return(false)
                allow(instance_group).to receive(:has_job?).with('job_name_2', 'release_name_2').and_return(false)
                expect(addon_include.applies?('', instance_group)).to be(false)
              end
            end
          end

          describe 'when the filter spec has both deployment section and jobs section' do
            let(:filter_hash) {
              {
                'deployments' => ['deployment_1', 'deployment_2'],
                'jobs' => [
                  {'name' => 'job_name', 'release' => 'release_name'},
                  {'name' => 'job_name_2', 'release' => 'release_name_2'}
                ]
              }
            }

            describe 'when the deployment name matches and the instance group contains the job' do
              it 'applies' do
                expect(instance_group).to receive(:has_job?).with('job_name', 'release_name').and_return(true)
                expect(addon_include.applies?('deployment_2', instance_group)).to be(true)
              end
            end

            describe 'when the deployment name does not match and the instance group contains job' do
              it 'does not apply' do
                allow(instance_group).to receive(:has_job?).with('job_name', 'release_name').and_return(true)
                expect(addon_include.applies?('deployment_3', instance_group)).to be(false)
              end
            end

            describe 'when the deployment name matches and the instance group does not contain all of the jobs' do
              it 'does not apply' do
                expect(instance_group).to receive(:has_job?).with('job_name', 'release_name').and_return(false)
                expect(instance_group).to receive(:has_job?).with('job_name_2', 'release_name_2').and_return(false)
                expect(addon_include.applies?('deployment_1', instance_group)).to be(false)
              end
            end
          end
        end

        context 'when there is a deployment filter' do
          let(:filter_hash) { {'deployments' => ['deployment_1', 'deployment_2']} }
          context 'when addon is in deployment manifest' do
            let(:addon_level) { DEPLOYMENT_LEVEL }
            it 'raises' do
              expect {
                addon_include
              }.to raise_error AddonDeploymentFilterNotAllowed,
                "Deployment filter is not allowed for deployment level addons."
            end
          end
          context 'when addon is not in deployment manifest' do
            let(:addon_level) { RUNTIME_LEVEL }
            it 'raises' do
              expect {
                addon_include
              }.not_to raise_error
            end
          end
        end
      end

      describe 'include' do
        let (:type) { :include }
        describe 'applies?' do
          describe 'when the include hash is nil' do
            let(:filter_hash) { nil }

            it 'applies' do
              expect(addon_include.applies?(nil, nil)).to be(true)
              expect(addon_include.applies?('anything', instance_group)).to be(true)
            end
          end

          it_behaves_like :common_filter_checks
        end
      end

      describe 'exclude' do
        let (:type) { :exclude }
        describe 'applies?' do
          describe 'when the include hash is nil' do
            let(:filter_hash) { nil }

            it 'does not apply' do
              expect(addon_include.applies?(nil, nil)).to be(false)
              expect(addon_include.applies?('anything', instance_group)).to be(false)
            end
          end

          it_behaves_like :common_filter_checks
        end
      end
    end
  end
end
