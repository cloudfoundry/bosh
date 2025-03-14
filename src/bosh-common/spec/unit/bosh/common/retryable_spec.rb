require 'spec_helper'

module Bosh::Common
  describe Retryable do
    before { allow(Kernel).to receive(:sleep) }
    class CustomMatcher
      def initialize(messages)
        @matching_messages = messages
      end

      def matches?(error)
        @matching_messages.include?(error.message)
      end
    end

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

      expect(count).to eq(3)
    end

    it 'should retry the given number of times when given error is raised' do
      count = 0

      described_class.new(tries: 3, on: [ArgumentError, RuntimeError]).retryer do |tries|
        count += 1
        raise ArgumentError if tries == 1
        raise RuntimeError if tries == 2
        true
      end

      expect(count).to eq(3)
    end

    context 'when sleeper raises retryable error' do
      let(:sleeper) { Proc.new { raise(sleeper_error_class, 'error-message') } }
      let(:sleeper_error_class) { Class.new(Exception) }
      let(:block_error_class) { Class.new(Exception) }

      context 'when error is raised in the sleeper block' do
        it 'should retry and return successfully' do
          count = 0
          described_class.new(tries: 2, on: [sleeper_error_class], sleep: sleeper).retryer do |tries|
            count += 1
            tries == 2 ? true : false
          end
          expect(count).to eq(2)
        end
      end

      context 'when error is raised in retryable block' do
        it 'should retry and return successfully' do
          count = 0
          described_class.new(tries: 2, on: [sleeper_error_class, block_error_class], sleep: sleeper).retryer do |tries|
            count += 1
            tries == 2 ? true : raise(block_error_class, 'yield-error')
          end
          expect(count).to eq(2)
        end
      end
    end

    context 'when sleeper raises non-retryable error' do
      let(:sleeper) { Proc.new { raise(sleeper_error_class, 'error-message') } }
      let(:sleeper_error_class) { Class.new(Exception) }
      let(:block_error_class) { Class.new(Exception) }

      context 'when error is raised in the sleeper block' do
        it 'does not retry and propagates sleeper error' do
          count = 0
          expect {
            described_class.new(tries: 2, on: [], sleep: sleeper).retryer do |_|
              count += 1
              false
            end
          }.to raise_error(sleeper_error_class, 'error-message')
          expect(count).to eq(1)
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
          expect(count).to eq(1)
        end
      end
    end

    it 'should retry the given number of times when matcher matches an error' do
      count = 0

      error_class = ArgumentError
      matcher = CustomMatcher.new(['fake-msg1', 'fake-msg2'])

      described_class.new(tries: 10, on: [error_class, matcher]).retryer do |tries|
        count += 1
        raise 'fake-msg1' if tries == 1
        raise ArgumentError if tries == 2
        raise 'fake-msg2' if tries == 3
        tries == 4
      end

      expect(count).to eq(4)
    end

    it 'should retry the given number of times when matcher matches an error raise from the sleeper' do
      count = 0

      sleeper = Proc.new do
        count += 1
        raise('fake-msg1') if count == 1
        raise('fake-msg2')
      end

      matcher = CustomMatcher.new(['fake-msg1'])

      expect {
        described_class.new(tries: 10, on: matcher, sleep: sleeper).retryer { false }
      }.to raise_error(RuntimeError, /fake-msg2/)

      expect(count).to eq(2)
    end

    it 'should retry when given error is raised and given message matches' do
      count = 0

      expect {
        described_class.new(tries: 3, on: StandardError, matching: /Ignore me/).retryer do |tries|
          count += 1
          tries <= 2 ? (raise StandardError, "Ignore me") : (raise StandardError)
        end
      }.to raise_error StandardError

      expect(count).to eq(3)
    end

    it 'should sleep on each retry the given number of seconds' do
      expect(Kernel).to receive(:sleep).with(5).twice

      described_class.new(tries: 3, on: StandardError, sleep: 5).retryer do |tries|
        raise StandardError if tries <= 2
        true
      end
    end

    it 'should pass error to sleep callback proc' do
      count = 0
      sleep_cb = lambda { |retries, error|
        expect(error.is_a?(ArgumentError)).to be(true) if retries == 1
        expect(error.is_a?(RuntimeError)).to be(true) if retries == 2
      }

      described_class.new(tries: 3, on: [ArgumentError, RuntimeError], sleep: sleep_cb).retryer do |tries|
        count += 1
        raise ArgumentError if tries == 1
        raise RuntimeError if tries == 2
        true
      end

      expect(count).to eq(3)
    end

    it 'should raise an error if that error is raised and is not in the specified list' do
      count = 0

      expect {
        described_class.new(on: [ArgumentError], tries: 3).retryer do
          count += 1
          raise ArgumentError if count < 2
          1 / 0
        end
      }.to raise_error(ZeroDivisionError)

      expect(count).to eq(2)
    end

    it 'should raise a RetryCountExceeded error if retries exceeded and block returns false' do
      count = 0

      expect {
        described_class.new(tries: 3).retryer do
          count += 1
          false
        end
      }.to raise_error(Bosh::Common::RetryCountExceeded)

      expect(count).to eq(3)
    end

    it 'should raise the original error if retries exceeded and error is raised in block' do
      count = 0

      expect {
        described_class.new(tries: 3, on: StandardError).retryer do
          count += 1
          raise StandardError
        end
      }.to raise_error(StandardError)

      expect(count).to eq(3)
    end
  end

  describe Retryable::ErrorMatcher do
    class Superclass < StandardError; end

    class Middleclass < Superclass; end

    class Subclass < Middleclass; end

    class Other < StandardError; end

    describe 'by_class' do
      let(:klass) { Middleclass }

      it 'returns an ErrorMatcher that matches any message' do
        expect(Retryable::ErrorMatcher).to receive(:new).with(klass, /.*/).and_call_original
        matcher = Retryable::ErrorMatcher.by_class(klass)
        expect(matcher).to be_an_instance_of(Retryable::ErrorMatcher)
        expect(matcher.matches?(klass.new('fake-message'))).to be(true)
      end
    end

    describe '#matches?' do
      subject { described_class.new(Middleclass, /match/) }
      let(:error) { klass.new(message) }

      context 'when error class matches provided class exactly' do
        let(:klass) { Middleclass }

        context 'when error messages matches provided message regex' do
          let(:message) { 'match' }
          it('returns true') { expect(subject.matches?(error)).to be(true) }
        end

        context 'when error messages does not match provided message regex' do
          let(:message) { 'other' }
          it('returns false') { expect(subject.matches?(error)).to be(false) }
        end
      end

      context 'when error class is a subclass of provided class' do
        let(:klass) { Subclass }

        context 'when error messages matches provided message regex' do
          let(:message) { 'match' }
          it('returns true') { expect(subject.matches?(error)).to be(true) }
        end

        context 'when error messages does not match provided message regex' do
          let(:message) { 'other' }
          it('returns false') { expect(subject.matches?(error)).to be(false) }
        end
      end

      context 'when error class is a superclass of provided class' do
        let(:klass) { Superclass }

        context 'when error messages matches provided message regex' do
          let(:message) { 'match' }
          it('returns false') { expect(subject.matches?(error)).to be(false) }
        end

        context 'when error messages does not match provided message regex' do
          let(:message) { 'other' }
          it('returns false') { expect(subject.matches?(error)).to be(false) }
        end
      end

      context 'when error class does not match provided class' do
        let(:klass) { Other }

        context 'when error messages matches provided message regex' do
          let(:message) { 'match' }
          it('returns false') { expect(subject.matches?(error)).to be(false) }
        end

        context 'when error messages does not match provided message regex' do
          let(:message) { 'other' }
          it('returns false') { expect(subject.matches?(error)).to be(false) }
        end
      end
    end
  end
end
