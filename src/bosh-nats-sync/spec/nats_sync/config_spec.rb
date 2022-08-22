require 'spec_helper'

describe NATSSync do
  describe '.config=' do
    after do
      File.open('my_log_file.log', 'r') do |f|
        File.delete(f)
      end
    end

    it 'should instantiate a logger with the given file path' do
      NATSSync.config = { 'logfile' => 'my_log_file.log' }
      expect(NATSSync.logger.level).to eq ::Logger::INFO
      expect(File).to exist('my_log_file.log')
    end
  end

  describe '.logger' do
    let(:log_file) { Tempfile.new('nats_log').path }
    let(:config) { { 'logfile' => log_file } }

    before do
      NATSSync.config = config
    end

    it 'returns a logger that logs to the specified config file' do
      NATSSync.logger.info('Test log 1')
      expect(File.read(log_file)).to include('Test log 1')
    end
  end
end
