require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe Env do
    describe '#spec' do
      it 'returns env' do
        env_spec =  {'key' => 'value'}
        env = Env.new(env_spec)
        expect(env.spec).to eq({'key' => 'value'})
      end
    end
  end
end
