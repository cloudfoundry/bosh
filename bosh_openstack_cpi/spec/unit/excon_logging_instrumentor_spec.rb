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
      expect(Bosh::OpenStackCloud::ExconLoggingInstrumentor::RedactedParams).
        to receive(:new).with(params)
      subject
    end

    it "yields" do
      expect{ |b| Bosh::OpenStackCloud::ExconLoggingInstrumentor.
        instrument(name, params, &b) }.to yield_control
    end
  end

  describe Bosh::OpenStackCloud::ExconLoggingInstrumentor::RedactedParams do
    describe "#redact_params" do
      let(:secret) { "secret_string" }
      subject(:redacted_params) {
        Bosh::OpenStackCloud::ExconLoggingInstrumentor::RedactedParams.new(params)
      }

      context "when containing a password" do
        let(:params) { {password: secret } }
        it "redacts password" do
          expect(redacted_params.to_s).to_not include secret
        end
      end

      context "when containing a authorization header" do
        let(:params) { {headers: { 'Authorization' => secret } } }
        it "redacts authorization" do
          expect(redacted_params.to_s).to_not include secret
        end
      end
    end
  end
end
