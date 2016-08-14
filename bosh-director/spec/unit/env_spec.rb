require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe Env do
    describe '#spec, #uninterpolated_spec' do
      it 'returns env and uninterpolated_env' do
        env_spec =  {'key' => 'value'}
        uninterpolated_env_spec =  {'key' => '((value))'}

        env = Env.new(env_spec, uninterpolated_env_spec)

        expect(env.spec).to eq({'key' => 'value'})
        expect(env.uninterpolated_spec).to eq({'key' => '((value))'})
      end
    end
  end
end
