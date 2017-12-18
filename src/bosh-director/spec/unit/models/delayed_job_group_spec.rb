require 'spec_helper'

module Bosh::Director::Models
  describe DelayedJobGroup do
    it 'extend sequel delayed_job model' do
      expect(Delayed::Backend::Sequel::Job.methods.include?(:all_blocked_jobs)).to be_truthy
    end
  end
end
