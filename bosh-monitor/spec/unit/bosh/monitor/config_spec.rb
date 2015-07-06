require 'spec_helper'

describe Bosh::Monitor do
  describe 'config=' do
    let(:http_config) { {} }
    let(:valid_config) { {
      'logfile' => Tempfile.new('logfile').path,
      'director' => {},
      'http' => http_config,
      'loglevel' => 'debug',
      'plugins' => %w(plugin1 plugin2)
    } }

    before do
      [:logger, :director, :intervals, :mbus, :event_mbus, :agent_manager, :event_processor,
       :http_port, :plugins, :nats].each do |accessor|
        Bosh::Monitor.send("#{accessor}=", nil)
      end
      Bosh::Monitor.config = valid_config
    end

    context 'with a valid configuration' do
      it 'should log to STDOUT when no logfile is provided' do
        valid_config.delete('logfile')
        Bosh::Monitor.config = valid_config
      end

      context 'without intervals' do
        it 'should set a default for prune_events' do
          expect(Bosh::Monitor.intervals.prune_events).to eq(30)
        end

        it 'should set a default for poll_director' do
          expect(Bosh::Monitor.intervals.poll_director).to eq(60)
        end

        it 'should set a default for poll_grace_period' do
          expect(Bosh::Monitor.intervals.poll_grace_period).to eq(30)
        end

        it 'should set a default for log_stats' do
          expect(Bosh::Monitor.intervals.log_stats).to eq(60)
        end

        it 'should set a default for analyze_agents' do
          expect(Bosh::Monitor.intervals.analyze_agents).to eq(60)
        end

        it 'should set a default for agent_timeout' do
          expect(Bosh::Monitor.intervals.agent_timeout).to eq(60)
        end

        it 'should set a default for rogue_agent_alert' do
          expect(Bosh::Monitor.intervals.rogue_agent_alert).to eq(120)
        end
      end

      context 'with http config' do
        let(:http_config) { {
            'port' => '1234',
        } }

        it 'should set http_port' do
          expect(Bosh::Monitor.http_port).to eq('1234')
        end
      end

      context 'with broken http config' do
        let(:http_config) { 6 }

        it 'should not set any http values' do
          expect(Bosh::Monitor.http_port).to be_nil
        end
      end

      context 'with event_mbus' do
        it 'should set event_mbus' do
          valid_config['event_mbus'] = { 'hello' => 'world' }
          Bosh::Monitor.config = valid_config

          expect(Bosh::Monitor.event_mbus.hello).to eq 'world'
        end
      end

      context 'without event_mbus' do
        it 'does not set the event_mbus' do
          expect(Bosh::Monitor.event_mbus).to be_nil
        end
      end

      context 'with loglevel' do
        it 'should set logger level' do
          expect(Bosh::Monitor.logger.level).to eq Logging::level_num(:debug)
        end
      end

      context 'with plugins' do
        it 'should set plugins' do
          expect(Bosh::Monitor.plugins).to eq %w(plugin1 plugin2)
        end
      end
    end

    context 'with an invalid configuration' do
      it 'should raise a ConfigError' do
        expect {
          Bosh::Monitor.config = 'not valid'
        }.to raise_error(Bosh::Monitor::ConfigError, 'Invalid config format, Hash expected, String given')
      end
    end
  end
end
