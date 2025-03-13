require 'spec_helper'

describe Bosh::Director::AuditLogger do
  let(:appenders) { double('test-appenders') }
  let(:logger) { double('test-logger') }
  let(:subject) { described_class.instance }

  describe '#info' do
    before do
      allow(Logging::Logger).to receive(:new).and_return(logger)
      allow(logger).to receive(:add_appenders)
      allow(logger).to receive(:level=)
      allow(logger).to receive(:info)

      allow(Logging).to receive(:appenders).and_return(appenders)
      allow(appenders).to receive(:file)

      allow(Bosh::Director::Config).to receive(:audit_filename).and_return('fake-log-file.log')
      allow(Bosh::Director::Config).to receive(:audit_log_path).and_return('/var/vcap/sys/log/director')
      allow(Bosh::Director::AuditLogger).to receive(:instance).and_call_original
    end

    it 'adds a file appender to appenders and calls logger.info' do
      subject.info('fake-log-message')

      expect(appenders).to have_received(:file).with(
        'DirectorAudit',
        hash_including(filename: File.join('/var/vcap/sys/log/director', 'fake-log-file.log')),
      )
      expect(logger).to have_received(:add_appenders)
      expect(logger).to have_received(:info).with('fake-log-message')
    end
  end
end
