require 'spec_helper'

describe Bosh::Director::TaggedLogger do
  subject(:tagged_logger) { described_class.new(per_spec_logger, 'tag-1', 'tag-2') }

  describe 'info' do
    context 'when multiple tags are passed in' do
      it 'appends tag to the message' do
        expect(per_spec_logger).to receive(:info).with('[tag-1][tag-2] log-message')
        tagged_logger.info('log-message')
      end
    end
  end

  describe 'error' do
    context 'when multiple tags are passed in' do
      it 'appends tag to the message' do
        expect(per_spec_logger).to receive(:error).with('[tag-1][tag-2] log-message')
        tagged_logger.error('log-message')
      end
    end
  end

  describe 'debug' do
    context 'when multiple tags are passed in' do
      it 'appends tag to the message' do
        expect(per_spec_logger).to receive(:debug).with('[tag-1][tag-2] log-message')
        tagged_logger.debug('log-message')
      end
    end
  end

  describe 'warn' do
    context 'when multiple tags are passed in' do
      it 'appends tag to the message' do
        expect(per_spec_logger).to receive(:warn).with('[tag-1][tag-2] log-message')
        tagged_logger.warn('log-message')
      end
    end
  end
end
