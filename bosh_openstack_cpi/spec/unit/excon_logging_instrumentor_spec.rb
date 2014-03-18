require "spec_helper"

describe Bosh::OpenStackCloud::ExconLoggingInstrumentor do
  describe ".instrument" do
    let(:name) { "foo" }
    let(:params) { { foo: "bar" } }
    let(:logger) { instance_double("Logger") }
    subject(:redacted_params) {
      Bosh::OpenStackCloud::ExconLoggingInstrumentor.instrument(name, params)
    }

    it "logs requests" do
      expect(Bosh::Clouds::Config).to receive(:logger).and_return(logger)
      expect(logger).to receive(:debug).with("#{name} #{params}")
      subject
    end

    it "redacts params" do
      expect(Bosh::OpenStackCloud::RedactedParams).
        to receive(:new).with(params)
      subject
    end

    it "yields" do
      expect{ |b| Bosh::OpenStackCloud::ExconLoggingInstrumentor.
        instrument(name, params, &b) }.to yield_control
    end
  end
end
