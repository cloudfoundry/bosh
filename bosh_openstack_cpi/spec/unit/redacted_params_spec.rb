require "spec_helper"

describe Bosh::OpenStackCloud::RedactedParams do
  describe "#redact_params" do
    let(:secret) { "secret_string" }
    subject(:redacted_params) {
      Bosh::OpenStackCloud::RedactedParams.new(params)
    }

    context "when containing a password" do
      let(:params) { { password: secret } }
      it "redacts password" do
        expect(redacted_params.to_s).to_not include secret
      end
    end

    context "when containing a authorization header" do
      let(:params) { { headers: { 'Authorization' => secret } } }
      it "redacts authorization" do
        expect(redacted_params.to_s).to_not include secret
      end
    end
  end
end
