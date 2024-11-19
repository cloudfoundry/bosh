require 'spec_helper'

module Bosh::Director
  describe Errand::LifecycleErrandStep do
    subject(:errand_step) do
      Errand::LifecycleErrandStep.new(
        runner,
        deployment_planner,
        errand_name,
        instance,
        instance_group,
        keep_alive,
        deployment_name,
        per_spec_logger,
      )
    end

    let(:deployment_planner) { instance_double(DeploymentPlan::Planner, template_blob_cache: template_blob_cache) }
    let(:runner) { instance_double(Errand::Runner) }
    let(:instance_group) { instance_double(DeploymentPlan::InstanceGroup, errand?: true) }
    let(:errand_name) { 'errand_name' }
    let(:template_blob_cache) { instance_double(Core::Templates::TemplateBlobCache) }
    let(:deployment_name) { 'deployment-name' }
    let(:errand_result) { Errand::Result.new(instance, errand_name, exit_code, nil, nil, nil) }
    let(:instance) do
      instance_double(DeploymentPlan::Instance,
                      uuid: '321-cba',
                      configuration_hash: instance_configuration_hash,
                      current_packages: { 'successful' => 'package_spec' })
    end
    let(:instance_configuration_hash) { 'abc123' }
    let(:keep_alive) { 'maybe' }
    let(:instance_group_manager) { instance_double(Errand::InstanceGroupManager) }
    let(:errand_instance_updater) { instance_double(Errand::ErrandInstanceUpdater) }

    before do
      allow(Errand::InstanceGroupManager).to receive(:new)
        .with(deployment_planner, instance_group, per_spec_logger)
        .and_return(instance_group_manager)
      allow(Errand::ErrandInstanceUpdater).to receive(:new)
        .with(instance_group_manager, per_spec_logger, errand_name, deployment_name)
        .and_return(errand_instance_updater)
    end

    describe '#prepare' do
      context 'when keep alive is true' do
        let(:keep_alive) { true }
        it 'updates instances with keep alive' do
          expect(errand_instance_updater).to receive(:create_vms).with(keep_alive)
          errand_step.prepare
        end
      end

      context 'when keep alive is false' do
        let(:keep_alive) { false }
        it 'updates instances without keep alive' do
          expect(errand_instance_updater).to receive(:create_vms).with(keep_alive)
          errand_step.prepare
        end
      end

      context 'when creating instances fails' do
        it 'should raise' do
          expect(errand_instance_updater).to receive(:create_vms).and_raise('OMG')
          expect { errand_step.prepare }.to raise_error('OMG')
        end
      end
    end

    describe '#run' do
      context 'success' do
        let(:exit_code) { 0 }

        it 'runs the errand' do
          allow(instance).to receive(:to_s).and_return('instance-name')
          expect(template_blob_cache).to receive(:clean_cache!)
          expect(errand_instance_updater).to receive(:with_updated_instances).with(keep_alive) do |&blk|
            blk.call
          end

          block_evidence = false
          the_block = lambda {
            block_evidence = true
          }

          expect(runner).to receive(:run).with(instance) do |&blk|
            blk.call
          end.and_return(errand_result)

          result = errand_step.run(&the_block)

          expect(block_evidence).to be(true)
          expect(result.successful?).to eq(true)
        end
      end

      context 'when something goes wrong' do
        it 'cleans the cache' do
          expect(template_blob_cache).to receive(:clean_cache!)
          expect(errand_instance_updater).to receive(:with_updated_instances).and_raise('omg')
          expect { errand_step.run(&-> {}) }.to raise_error 'omg'
        end
      end
    end

    describe '#state_hash' do
      it 'returns digest of instance uuid, configuration_hash, and package_spec' do
        expect(errand_step.state_hash).to eq(::Digest::SHA1.hexdigest('321-cbaabc123{"successful"=>"package_spec"}'))
      end

      describe 'when the instance configuration hash is nil' do
        let(:instance_configuration_hash) { nil }
        it 'returns digest of instance uuid, and package_spec' do
          expect(errand_step.state_hash).to eq(::Digest::SHA1.hexdigest('321-cba{"successful"=>"package_spec"}'))
        end
      end
    end
  end
end
