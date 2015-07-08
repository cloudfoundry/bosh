require 'spec_helper'

module Support
  module FakeLocks
    def fake_locks
      lock = instance_double('Bosh::Director::Lock')
      allow(Bosh::Director::Lock).to receive(:new).and_return(lock)
      allow(lock).to receive(:release)
      allow(lock).to receive(:lock)
    end
  end
end

RSpec.configure do |config|
  config.include(Support::FakeLocks)
end
