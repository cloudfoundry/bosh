module Support
  module FakeLocks
    class FakeLock
      def lock
        yield if block_given?
      end

      def release
      end
    end

    def fake_locks
      allow(Bosh::Director::Lock).to receive(:new).and_return(FakeLock.new)
    end
  end
end

RSpec.configure do |config|
  config.include(Support::FakeLocks)
end
