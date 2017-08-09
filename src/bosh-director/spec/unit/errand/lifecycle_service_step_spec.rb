require 'spec_helper'

module Bosh::Director
  describe Errand::LifecycleServiceStep do
    subject(:errand_step) { Errand::LifecycleServiceStep.new(runner, instance, logger) }
    let(:runner) { instance_double(Errand::Runner) }
    let(:errand_name) { 'errand_name' }
    let(:errand_result) { Errand::Result.new(errand_name, exit_code, nil, nil, nil) }
    let(:instance) { instance_double(DeploymentPlan::Instance, uuid: '321-cba', configuration_hash: instance_configuration_hash, current_packages: {'successful' => 'package_spec'}) }
    let(:instance_configuration_hash) { 'abc123' }
    let(:exit_code) { 0 }

    describe '#prepare' do
      it 'does nothing' do
        expect(errand_step.prepare).to eq(nil)
      end
    end

    describe '#ignore_cancellation?' do
      it 'returns false' do
        expect(errand_step.ignore_cancellation?).to eq(false)
      end
    end

    describe '#run' do
      let(:checkpoint_block) { Proc.new {} }

      it 'returns the result' do
        expect(runner).to receive(:run).with(instance, &checkpoint_block).
          and_return(errand_result)
        result = errand_step.run(&checkpoint_block)
        expect(result.successful?).to eq(true)
        expect(result.exit_code).to eq(0)
      end
    end

    describe '#state_hash' do
      it 'returns digest of instance uuid, configuration_hash, and package_spec' do
        expect(errand_step.state_hash).to eq(::Digest::SHA1.hexdigest('321-cbaabc123{"successful"=>"package_spec"}'))
      end

      context 'when the instance confuguration hash is nil' do
        let(:instance_configuration_hash) { nil }

        it 'returns digest of instance uuid and package spec' do
          expect(errand_step.state_hash).to eq(::Digest::SHA1.hexdigest('321-cba{"successful"=>"package_spec"}'))
        end
      end
    end
  end
end
