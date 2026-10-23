require 'spec_helper'

module Bosh::Monitor
  describe 'Metric connections' do
    let(:logger) { instance_double(Logger, debug: nil, warn: nil) }
    let(:graphite) { GraphiteConnection.new('localhost', 2003, 0) }
    let(:tsdb) { TsdbConnection.new('localhost', 4242, 0) }

    before do
      allow(Bosh::Monitor).to receive(:logger).and_return(logger)
      allow(graphite).to receive(:send_data)
      allow(tsdb).to receive(:send_data)
    end

    it 'sends normal Graphite values including zero' do
      expect(graphite).to receive(:send_data).with("test.metric 0 1234567890\n")
      graphite.send_metric('test.metric', 0, 1234567890)
    end

    it 'sends normal TSDB values and sorted tags' do
      expect(tsdb).to receive(:send_data).with("put test.metric 1234567890 1.5 index=0 job=api\n")
      tsdb.send_metric('test.metric', 1234567890, '1.5', 'job' => 'api', 'index' => '0')
    end

    ["0 1234567890\nfake.metric 9999", "1\rdropcaches", "1\t2", "1\x00", ''].each do |value|
      it "rejects Graphite value #{value.inspect}" do
        expect(graphite).not_to receive(:send_data)
        graphite.send_metric('test.metric', value, 1234567890)
      end

      it "rejects TSDB value #{value.inspect}" do
        expect(tsdb).not_to receive(:send_data)
        tsdb.send_metric('test.metric', 1234567890, value)
      end
    end

    it 'rejects a TSDB tag value containing another command' do
      expect(tsdb).not_to receive(:send_data)
      tsdb.send_metric('test.metric', 1234567890, 1, 'index' => "0\ndropcaches")
    end

    it 'rejects a TSDB tag key containing whitespace' do
      expect(tsdb).not_to receive(:send_data)
      tsdb.send_metric('test.metric', 1234567890, 1, "index\n" => '0')
    end

    it 'rejects missing fields without logging their contents' do
      expect(graphite).not_to receive(:send_data)
      expect(logger).to receive(:warn).with('Invalid graphite metric')
      graphite.send_metric(nil, 1, 1234567890)
    end
  end
end
