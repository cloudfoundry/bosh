require "spec_helper"

describe Bosh::OpenStackCloud::ExconLoggingInstrumentor do
  describe ".instrument" do
    let(:name) { "foo" }
    let(:params) { { foo: "bar" } }
    let(:logger) { instance_double("Logger") }
    let(:cpi_log) { "foo/bar"}
    subject(:redacted_params) {
      Bosh::OpenStackCloud::ExconLoggingInstrumentor.instrument(name, params)
    }

    before do
      allow(Bosh::Clouds::Config).to receive(:cpi_task_log).and_return(cpi_log)
      allow(Logger).to receive(:new).with(cpi_log).and_return(logger)
      allow(logger).to receive(:debug)
      allow(logger).to receive(:close)
    end

    it "logs requests" do
      expect(Bosh::Clouds::Config).to receive(:logger).and_return(logger)
      expect(logger).to receive(:debug).with("#{name} #{params}")
      subject
    end

    it "redacts params" do
      expect(Bosh::OpenStackCloud::RedactedParams).to receive(:new).with(params)
      subject
    end

    it "yields" do
      expect { |b| Bosh::OpenStackCloud::ExconLoggingInstrumentor.instrument(name, params, &b) }.to yield_control
    end

    it "closes the logger" do
      expect(logger).to receive(:close)
      subject
    end
  end
end
