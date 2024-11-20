require 'bosh/director/thread_pool'

RSpec.configure do |config|
  config.before(:each) do
    thread_pool = instance_double(Bosh::Director::ThreadPool)
    allow(Bosh::Director::ThreadPool).to receive(:new).and_return(thread_pool)

    allow(thread_pool).to receive(:wrap).and_yield(thread_pool)
    allow(thread_pool).to receive(:process).and_yield
    allow(thread_pool).to receive(:wait)
  end
end
