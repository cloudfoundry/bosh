require 'spec_helper'

describe '20151031001039_add_spec_to_instance' do
  include Migrations

  before do
    during_migration('director') do |migration, db|
      migration.stop_before('20151031001039_add_spec_to_instance')

      # Why do we have to 'bind' Bosh::Director::Models::Deployment
      migration.reset_models(Bosh::Director::Models::Vm, Bosh::Director::Models::Instance, Bosh::Director::Models::Deployment)

      deployment = Bosh::Director::Models::Deployment.create({
          name: 'deployment'
        })

      vm = Bosh::Director::Models::Vm.create({
          cid: 123,
          deployment: deployment,
          agent_id: SecureRandom.uuid,
          apply_spec_json: Yajl::Encoder.encode({
              'empty' => 'value'
            })
        })
      @vm_id = vm.id

      @instance_id = Bosh::Director::Models::Instance.create({
          deployment: deployment,
          job: 'job',
          index: 0,
          state: 'started',
          vm: vm
        }).id

      migration.stop_after('20151031001039_add_spec_to_instance')

      migration.reset_models(Bosh::Director::Models::Vm, Bosh::Director::Models::Instance, Bosh::Director::Models::Deployment)
    end
  end

  it 'moves "Vm.apply_spec_json" to "Instance.spec_json"' do
    vm = Bosh::Director::Models::Vm.where(id: @vm_id).first
    instance = Bosh::Director::Models::Instance.where(id: @instance_id).first

    expect(Yajl::Parser.parse(instance.spec_json)).to eq({
          'empty' => 'value'
        })

    expect(vm.apply_spec_json).to eq(nil)
  end
end