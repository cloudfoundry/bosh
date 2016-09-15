require 'spec_helper'

module Bosh::Director::Api
  describe SyslogHelper do
    include SyslogHelper

    describe '.syslog_supported' do
      it 'is true if RUBY_VERSION.to_i > 1' do
        expect(SyslogHelper.syslog_supported).to eq(RUBY_VERSION.to_i > 1)
      end
    end

    describe '#syslog' do
      context 'when syslog is supported' do

        it 'logs to syslog' do
          pending("Syslog::Logger does not exist in ruby version '#{RUBY_VERSION}'") if RUBY_VERSION.to_i < 2

          logger = instance_double(Syslog::Logger)
          allow(Syslog::Logger).to receive(:new).with('vcap.bosh.director').and_return(logger)
          allow(logger).to receive(:info)

          syslog(:info, 'message')

          expect(logger).to have_received(:info).with('message')
        end
      end

      context 'when syslog is not supported' do
        before(:each) do
          allow(SyslogHelper).to receive(:syslog_supported).and_return(false)
        end

        it 'does not raise error' do
          expect {
            syslog(:info, 'message')
          }.to_not raise_error
        end
      end

    end
  end
end
