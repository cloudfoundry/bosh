require 'spec_helper'

describe Bosh::Monitor::TcpConnection do
  describe "exponential back off" do
    context "when the initial connection fails" do
      let(:tcp_connection) { Bosh::Monitor::TcpConnection.new("signature", "connection.tcp", "127.0.0.1", 80) }

      before { Bhm.logger = logger }

      it "tries to reconnect when unbinding" do
        expect(EM).to receive(:add_timer).with(0)
        tcp_connection.unbind
      end

      it "doesn't log on the first unbind" do
        allow(EM).to receive(:add_timer)
        expect(logger).to_not receive(:info)
        tcp_connection.unbind
      end

      it "logs on subsequent unbinds" do
        allow(EM).to receive(:add_timer)
        tcp_connection.unbind
        expect(logger).to receive(:info).with('connection.tcp-failed-to-reconnect, will try again in 1 seconds...')
        tcp_connection.unbind
      end


      it "takes exponentially longer" do
        expect(EM).to receive(:add_timer).with(0)
        tcp_connection.unbind
        expect(EM).to receive(:add_timer).with(1)
        tcp_connection.unbind
        expect(EM).to receive(:add_timer).with(3)
        tcp_connection.unbind
      end

      it "should exit after MAX_RETRIES retries" do
        allow(EM).to receive(:add_timer)

        expect do
          (Bosh::Monitor::TcpConnection::MAX_RETRIES + 1).times do
            tcp_connection.unbind
          end
        end.to raise_error(/connection.tcp-failed-to-reconnect after/)
      end
    end
  end
end
