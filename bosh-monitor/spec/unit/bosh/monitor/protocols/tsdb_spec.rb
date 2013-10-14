require 'spec_helper'

describe Bosh::Monitor::TsdbConnection do
  describe "exponential back off" do
    context "when the initial connection fails" do
      let(:tsdb_connection) { Bosh::Monitor::TsdbConnection.new("signature", "127.0.0.1", 80) }
      let(:fake_logger) { double("fake_logger").as_null_object }

      before do
        Bhm.should_receive(:logger).and_return(fake_logger)
      end


      it "tries to reconnect when unbinding" do
        EM.should_receive(:add_timer).with(0)
        tsdb_connection.unbind
      end

      it "doesn't log on the first unbind" do
        EM.stub(:add_timer)
        fake_logger.should_not_receive(:info)
        tsdb_connection.unbind
      end

      it "logs on subsequent unbinds" do
        EM.stub(:add_timer)
        tsdb_connection.unbind
        fake_logger.should_receive(:info).with("Failed to reconnect to TSDB, will try again in 1 seconds...")
        tsdb_connection.unbind
      end


      it "takes exponentially longer" do
        EM.should_receive(:add_timer).with(0)
        tsdb_connection.unbind
        EM.should_receive(:add_timer).with(1)
        tsdb_connection.unbind
        EM.should_receive(:add_timer).with(3)
        tsdb_connection.unbind
      end

      it "should exit after MAX_RETRIES retries" do
        EM.stub(:add_timer)

        expect do
          (Bosh::Monitor::TsdbConnection::MAX_RETRIES + 1).times do
            tsdb_connection.unbind
          end
        end.to raise_error(/Failed to reconnect to TSDB after/)
      end
    end
  end
end
