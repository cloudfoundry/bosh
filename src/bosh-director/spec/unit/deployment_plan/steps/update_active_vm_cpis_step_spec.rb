require 'spec_helper'

module Bosh::Director
  module DeploymentPlan::Steps
    describe UpdateActiveVmCpisStep do
      subject do
        deployment_assembler.bind_models
        described_class.new(base_job.logger, deployment_plan)
      end
      let(:base_job) { Bosh::Director::Jobs::BaseJob.new }

      let!(:variable_set) { Models::VariableSet.make(deployment: deployment_model) }
      let(:deployment_model) do
        deployment = Models::Deployment.make(name: 'fake-deployment', manifest: YAML.dump(deployment_manifest))
        deployment.cloud_configs = [cloud_config]
        deployment
      end
      let(:deployment_plan) do
        planner_factory = Bosh::Director::DeploymentPlan::PlannerFactory.create(logger)
        deployment_plan = planner_factory.create_from_model(deployment_model)

        agent_client = instance_double('Bosh::Director::AgentClient')
        allow(BD::AgentClient).to receive(:with_agent_id).and_return(agent_client)
        allow(agent_client).to receive(:get_state).and_return({'agent-state' => 'yes'})

        deployment_plan
      end

      let (:deployment_assembler) { DeploymentPlan::Assembler.create(deployment_plan) }

      let!(:stemcell) { Models::Stemcell.make(name: 'ubuntu-stemcell', version: '1') }
      let!(:cloud_config) {
        if prior_az_name.nil?
          Models::Config.make(:cloud_with_manifest)
        else
          raw_manifest = Bosh::Spec::Deployments.simple_cloud_config.merge({
            'azs' => [
              {
                'name' => prior_az_name,
                'cpi' => 'cpi-new',
              },
            ],
          })
          raw_manifest['networks'][0]['subnets'][0]['azs'] = [prior_az_name]
          raw_manifest['compilation']['az'] = prior_az_name

          Models::Config.make(:cloud, raw_manifest: raw_manifest)
        end
      }
      let(:prior_az_name) { 'z2' }
      let!(:cpi_config) { Models::CpiConfig.make }
      let(:deployment_manifest) do
        manifest = {
          'name' => 'fake-deployment',
          'releases' => [],
          'instance_groups' => [
            {
              'name' => 'fake-instance-group',
              'jobs' => [],
              'resource_pool' => 'a',
              'instances' => 1,
              'networks' => [
                {
                  'name' => 'a',
                },
              ],
            }
          ],
          'update' => {
            'canaries' => 1,
            'max_in_flight' => 1,
            'canary_watch_time' => 1,
            'update_watch_time' => 1,
          },
        }
        if !prior_az_name.nil?
          manifest['instance_groups'][0]['azs'] = [ prior_az_name ]
        end
        manifest
      end

      before do
        Bosh::Director::App.new(Bosh::Director::Config.load_hash(SpecHelper.spec_get_director_config))

        allow(base_job).to receive(:task_id).and_return(1)
        allow(Bosh::Director::Config).to receive(:current_job).and_return(base_job)
      end

      describe '#perform' do
        context 'with instances in the deployment' do
          let(:existing_instance) {
            Models::Instance.make(deployment: deployment_model, job: 'fake-instance-group', index: 0, availability_zone: prior_az_name, variable_set: variable_set)
          }

          context 'with no AZ name (legacy-style manifest)' do
            let(:prior_az_name) { '' }
            before {
              existing_instance.active_vm = Models::Vm.make(cpi: 'anything', instance: existing_instance)
              existing_instance.save
            }

            it 'sets the CPI name to empty' do
              subject.perform
              expect(Models::Instance.all.count).to eq 1
              expect(Models::Vm.all[0].cpi).to eq('')
            end
          end

          context 'with nil azs (key not specified in manifest)' do
            let(:prior_az_name) { nil }
            before {
              existing_instance.active_vm = Models::Vm.make(cpi: 'anything', instance: existing_instance)
              existing_instance.save
            }

            it 'sets the CPI name to empty' do
              subject.perform
              expect(Models::Instance.all.count).to eq 1
              expect(Models::Vm.all[0].cpi).to eq('')
            end
          end


          context 'with an AZ name that exists in the new cloud config' do
            let(:prior_az_name) { 'z2' }

            context 'when there are no VMs' do
              it 'does not create new VMs' do
                subject.perform
                expect(Models::Vm.count).to eq(0)
              end
            end

            context 'with a VM for the instance' do
              before { existing_instance.active_vm = Models::Vm.make(cpi: prior_cpi_name, instance: existing_instance) }

              context 'which has an outdated cpi name' do
                let(:prior_cpi_name) { 'cpi-old' }
                it 'updates them' do
                  subject.perform
                  expect(Models::Vm.all[0].cpi).to eq('cpi-new')
                end
              end

              context 'which has the correct cpi name already' do
                let(:prior_cpi_name) { 'cpi-new' }
                it 'leaves the cpi as-is' do
                  subject.perform
                  expect(Models::Vm.all[0].cpi).to eq('cpi-new')
                end
              end
            end

            context 'when an errand was kept alive' do
              let(:deployment_manifest) do
                {
                  'name' => 'fake-deployment',
                  'releases' => [],
                  'instance_groups' => [
                    {
                      'name' => 'fake-instance-group',
                      'azs' => ['z2'],
                      'jobs' => [],
                      'lifecycle' => 'errand',
                      'resource_pool' => 'a',
                      'instances' => 1,
                      'networks' => [
                        {
                          'name' => 'a',
                        }
                      ],
                    }
                  ],
                  'update' => {
                    'canaries' => 1,
                    'max_in_flight' => 1,
                    'canary_watch_time' => 1,
                    'update_watch_time' => 1,
                  },
                }
              end

              before { existing_instance.active_vm = Models::Vm.make(cpi: 'old-cpi', instance: existing_instance) }
              it 'updates the cpi' do
                subject.perform

                # instance should have new cpi set
                expect(Models::Vm.all[0].cpi).to eq('cpi-new')
              end
            end
          end
        end
      end
    end
  end
end
