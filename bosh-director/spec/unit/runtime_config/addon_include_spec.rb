require 'spec_helper'

module Bosh::Director
  module RuntimeConfig
    describe AddonInclude do
      subject(:addon_include) { AddonInclude.parse(include_hash) }
      let(:instance_group) { instance_double(DeploymentPlan::InstanceGroup) }

      describe 'applies?' do
        describe 'when the include hash is nil' do
          let(:include_hash) { nil }

          it 'applies' do
            expect(addon_include.applies?(nil, nil)).to be(true)
            expect(addon_include.applies?('anything', instance_group)).to be(true)
          end
        end

        describe 'when the include has a job with an empty job name' do
          let(:include_hash) { {'jobs' => [{'name' => '', 'release' => 'release_name'}]} }

          it 'raises' do
            expect {
              addon_include.applies?('anything', instance_group)
            }.to raise_error RuntimeIncompleteIncludeJobSection,
              "Job {\"name\"=>\"\", \"release\"=>\"release_name\"} in runtime config's include section must have both name and release."
          end
        end

        describe 'when the include has a job with a missing release name' do
          let(:include_hash) { {'jobs' => [{'name' => 'job-name', 'release' => ''}]} }

          it 'raises' do
            expect {
              addon_include.applies?('anything', instance_group)
            }.to raise_error RuntimeIncompleteIncludeJobSection,
              "Job {\"name\"=>\"job-name\", \"release\"=>\"\"} in runtime config's include section must have both name and release."
          end
        end

        describe 'when the include has a stemcell property' do
          describe 'when the stemcell property has an os missing a name' do
            let(:include_hash) { {'stemcell' => [{'os' => ''}]} }

            it 'raises' do
              expect {
                addon_include.applies?('anything', instance_group)
              }.to raise_error RuntimeIncompleteIncludeStemcellSection,
                "Stemcell {\"os\"=>\"\"} in runtime config's include section must have an os name."
            end
          end

          describe 'when the stemcell os matches the instance group stemcell os' do
            let(:include_hash) { {'stemcell' => [{'os' => 'my_os'}]} }

            it 'applies' do
              allow(instance_group).to receive(:has_os?).with('my_os').and_return(true)
              expect(addon_include.applies?('anything', instance_group)).to be(true)
            end
          end

          describe 'when the stemcell os does not match the instance group stemcell os' do
            let(:include_hash) { {'stemcell' => [{'os' => 'my_os'}]} }

            it 'does not apply' do
              allow(instance_group).to receive(:has_os?).with('my_os').and_return(false)
              expect(addon_include.applies?('anything', instance_group)).to be(false)
            end
          end
        end

        describe 'when the include spec has only a deployments section' do
          let(:include_hash) { {'deployments' => ['deployment_1', 'deployment_2']} }

          describe 'when the deployment name matches one from the include spec' do
            it 'applies' do
              expect(addon_include.applies?('deployment_1', nil)).to be(true)
            end
          end

          describe 'when the deployment name does not match one from the include spec' do
            it 'does not apply' do
              expect(addon_include.applies?('deployment_blarg', nil)).to be(false)
            end
          end
        end

        describe 'when the include spec has only a jobs section' do
          let(:include_hash) { {'jobs' => [{'name' => 'job_name', 'release' => 'release_name'}]} }

          describe 'when the instance group contains a matching job from the include spec' do
            it 'applies' do
              allow(instance_group).to receive(:has_job?).with('job_name', 'release_name').and_return(true)
              expect(addon_include.applies?('', instance_group)).to be(true)
            end
          end

          describe 'when the instance group does not contain a matching job from the include spec' do
            it 'does not apply' do
              allow(instance_group).to receive(:has_job?).with('job_name', 'release_name').and_return(false)
              expect(addon_include.applies?('', instance_group)).to be(false)
            end
          end

          describe 'when there are multiple jobs on the include spec' do
            let(:include_hash) {
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

          describe 'when the include spec has both deployment section and jobs section' do
            let(:include_hash) {
              {
                'deployments' => ['deployment_1', 'deployment_2'],
                'jobs' => [
                  {'name' => 'job_name', 'release' => 'release_name'},
                  {'name' => 'job_name_2', 'release' => 'release_name_2'}
                ]
              }
            }

            describe 'when the deployment name matches and the instance group contains all of the jobs' do
              it 'applies' do
                expect(instance_group).to receive(:has_job?).with('job_name', 'release_name').and_return(true)
                expect(addon_include.applies?('deployment_2', instance_group)).to be(true)
              end
            end

            describe 'when the deployment name does not matche and the instance group does not contain' do
              it 'applies' do
                allow(instance_group).to receive(:has_job?).with('job_name', 'release_name').and_return(true)
                expect(addon_include.applies?('deployment_3', instance_group)).to be(false)
              end
            end

            describe 'when the deployment name matches and the instance group contains all of the jobs' do
              it 'applies' do
                expect(instance_group).to receive(:has_job?).with('job_name', 'release_name').and_return(false)
                expect(instance_group).to receive(:has_job?).with('job_name_2', 'release_name_2').and_return(false)
                expect(addon_include.applies?('deployment_1', instance_group)).to be(false)
              end
            end
          end
        end
      end
    end
  end
end
