require 'spec_helper'
require 'common/retryable'

describe Bosh::Retryable do
  before { Kernel.stub(:sleep) }

  it 'should raise an ArgumentError error if invalid options are used' do
    expect {
      described_class.new(foo: 'bar')
    }.to raise_error(ArgumentError, /Invalid options/)
  end

  it 'should retry the given number of times if false is returned' do
    count = 0

    described_class.new(tries: 3, on: StandardError).retryer do |tries|
      count += 1
       tries < 3 ? false : true
    end

    count.should == 3
  end

  it 'should retry the given number of times when given error is raised' do
    count = 0

    described_class.new(tries: 3, on: [ArgumentError, RuntimeError]).retryer do |tries|
      count += 1
      raise ArgumentError if tries == 1
      raise RuntimeError if tries == 2
      true
    end

    count.should == 3
  end

  context 'when sleeper raises retryable error' do
    let(:sleeper) { Proc.new { raise(sleeper_error_class, 'error-message') } }
    let(:sleeper_error_class) { Class.new(Exception) }
    let(:block_error_class)   { Class.new(Exception) }

    context 'when error is raised in the sleeper block' do
      it 'should retry and return successfully' do
        count = 0
        described_class.new(tries: 2, on: [sleeper_error_class], sleep: sleeper).retryer do |tries|
          count += 1
          tries == 2 ? true : false
        end
        count.should == 2
      end
    end

    context 'when error is raised in retryable block' do
      it 'should retry and return successfully' do
        count = 0
        described_class.new(tries: 2, on: [sleeper_error_class, block_error_class], sleep: sleeper).retryer do |tries|
          count += 1
          tries == 2 ? true : raise(block_error_class, 'yield-error')
        end
        count.should == 2
      end
    end
  end

  context 'when sleeper raises non-retryable error' do
    let(:sleeper) { Proc.new { raise(sleeper_error_class, 'error-message') } }
    let(:sleeper_error_class) { Class.new(Exception) }
    let(:block_error_class)   { Class.new(Exception) }

    context 'when error is raised in the sleeper block' do
      it 'does not retry and propagates sleeper error' do
        count = 0
        expect {
          described_class.new(tries: 2, on: [], sleep: sleeper).retryer do |_|
            count += 1
            false
          end
        }.to raise_error(sleeper_error_class, 'error-message')
        count.should == 1
      end
    end

    context 'when error is raised in retryable block' do
      it 'does not retry and propagates sleeper error instead of propagating retryable error' do
        count = 0
        expect {
          described_class.new(tries: 2, on: [block_error_class], sleep: sleeper).retryer do |_|
            count += 1
            raise(block_error_class, 'yield-error')
          end
        }.to raise_error(sleeper_error_class, 'error-message')
        count.should == 1
      end
    end
  end

  it 'should retry when given error is raised and given message matches' do
    count = 0

    expect {
      described_class.new(tries: 3, on: StandardError, matching: /Ignore me/).retryer do |tries|
        count += 1
        tries <= 2 ? (raise StandardError, "Ignore me") : (raise StandardError)
      end
    }.to raise_error StandardError

    count.should == 3
  end

  it 'should sleep on each retry the given number of seconds' do
    Kernel.should_receive(:sleep).with(5).twice

    described_class.new(tries: 3, on: StandardError, sleep: 5).retryer do |tries|
      raise StandardError if tries <= 2
      true
    end
  end

  it 'should pass error to sleep callback proc' do
    count = 0
    sleep_cb = lambda { |retries, error|
      error.is_a?(ArgumentError).should be(true) if retries == 1
      error.is_a?(RuntimeError).should be(true) if retries == 2
    }

    described_class.new(tries: 3, on: [ArgumentError, RuntimeError], sleep: sleep_cb).retryer do |tries|
      count += 1
      raise ArgumentError if tries == 1
      raise RuntimeError if tries == 2
      true
    end

    count.should == 3
  end

  it 'should raise an error if that error is raised and is not in the specified list' do
    count = 0

    expect {
      described_class.new(on: [ArgumentError], tries: 3).retryer do
        count += 1
        raise ArgumentError if count < 2
        1/0
      end
    }.to raise_error(ZeroDivisionError)

    count.should == 2
  end

  it 'should raise a RetryCountExceeded error if retries exceeded and block returns false' do
    count = 0

    expect {
      described_class.new(tries: 3).retryer do
        count += 1
        false
      end
    }.to raise_error(Bosh::Common::RetryCountExceeded)

    count.should == 3
  end

  it 'should raise the original error if retries exceeded and error is raised in block' do
    count = 0

    expect {
      described_class.new(tries: 3, on: StandardError).retryer do
        count += 1
        raise StandardError
      end
    }.to raise_error(StandardError)

    count.should == 3
  end
end
