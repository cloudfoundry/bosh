require 'spec_helper'

describe Bosh::Monitor::TsdbConnection do
  describe "exponential back off" do
    context "when the initial connection fails" do
      let(:tsdb_connection) { Bosh::Monitor::TsdbConnection.new("signature", "127.0.0.1", 80) }

      before { Bhm.logger = logger }

      it "tries to reconnect when unbinding" do
        expect(EM).to receive(:add_timer).with(0)
        tsdb_connection.unbind
      end

      it "doesn't log on the first unbind" do
        allow(EM).to receive(:add_timer)
        expect(logger).to_not receive(:info)
        tsdb_connection.unbind
      end

      it "logs on subsequent unbinds" do
        allow(EM).to receive(:add_timer)
        tsdb_connection.unbind
        expect(logger).to receive(:info).with('Failed to reconnect to TSDB, will try again in 1 seconds...')
        tsdb_connection.unbind
      end


      it "takes exponentially longer" do
        expect(EM).to receive(:add_timer).with(0)
        tsdb_connection.unbind
        expect(EM).to receive(:add_timer).with(1)
        tsdb_connection.unbind
        expect(EM).to receive(:add_timer).with(3)
        tsdb_connection.unbind
      end

      it "should exit after MAX_RETRIES retries" do
        allow(EM).to receive(:add_timer)

        expect do
          (Bosh::Monitor::TsdbConnection::MAX_RETRIES + 1).times do
            tsdb_connection.unbind
          end
        end.to raise_error(/Failed to reconnect to TSDB after/)
      end
    end
  end
end
