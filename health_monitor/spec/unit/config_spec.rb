require 'spec_helper'

describe Bosh::HealthMonitor do
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
       :http_port, :http_user, :http_password, :plugins, :varz , :nats].each do |accessor|
        Bosh::HealthMonitor.send("#{accessor}=", nil)
      end
      Bosh::HealthMonitor.config = valid_config
    end

    context 'with a valid configuration' do
      it 'should log to STDOUT when no logfile is provided' do
        valid_config.delete('logfile')
        Logging.should_receive(:logger).with(STDOUT).and_return(double(Logging::Logger).as_null_object)
        Bosh::HealthMonitor.config = valid_config
      end

      context 'without intervals' do
        it 'should set a default for prune_events' do
          expect(Bosh::HealthMonitor.intervals.prune_events).to eq(30)
        end

        it 'should set a default for poll_director' do
          expect(Bosh::HealthMonitor.intervals.poll_director).to eq(60)
        end

        it 'should set a default for poll_grace_period' do
          expect(Bosh::HealthMonitor.intervals.poll_grace_period).to eq(30)
        end

        it 'should set a default for log_stats' do
          expect(Bosh::HealthMonitor.intervals.log_stats).to eq(60)
        end

        it 'should set a default for analyze_agents' do
          expect(Bosh::HealthMonitor.intervals.analyze_agents).to eq(60)
        end

        it 'should set a default for agent_timeout' do
          expect(Bosh::HealthMonitor.intervals.agent_timeout).to eq(60)
        end

        it 'should set a default for rogue_agent_alert' do
          expect(Bosh::HealthMonitor.intervals.rogue_agent_alert).to eq(120)
        end
      end

      context 'with http config' do
        let(:http_config) { {
            'port' => '1234',
            'user' => 'root',
            'password' => 'passw0rd'
        } }

        it 'should set http_port' do
          expect(Bosh::HealthMonitor.http_port).to eq('1234')
        end

        it 'should set http_user' do
          expect(Bosh::HealthMonitor.http_user).to eq('root')
        end

        it 'should set http_password' do
          expect(Bosh::HealthMonitor.http_password).to eq('passw0rd')
        end
      end

      context 'with broken http config' do
        let(:http_config) { 6 }

        it 'should not set any http values' do
          expect(Bosh::HealthMonitor.http_port).to be_nil
          expect(Bosh::HealthMonitor.http_user).to be_nil
          expect(Bosh::HealthMonitor.http_password).to be_nil
        end
      end

      context 'with event_mbus' do
        it 'should set event_mbus' do
          valid_config['event_mbus'] = { 'hello' => 'world' }
          Bosh::HealthMonitor.config = valid_config

          expect(Bosh::HealthMonitor.event_mbus.hello).to eq 'world'
        end
      end

      context 'without event_mbus' do
        it 'does not set the event_mbus' do
          expect(Bosh::HealthMonitor.event_mbus).to be_nil
        end
      end

      context 'with loglevel' do
        it 'should set logger level' do
          expect(Bosh::HealthMonitor.logger.level).to eq Logging::level_num(:debug)
        end
      end

      context 'with plugins' do
        it 'should set plugins' do
          expect(Bosh::HealthMonitor.plugins).to eq %w(plugin1 plugin2)
        end
      end
    end

    context 'with an invalid configuration' do
      it 'should raise a ConfigError' do
        expect {
          Bosh::HealthMonitor.config = 'not valid'
        }.to raise_error(Bosh::HealthMonitor::ConfigError, 'Invalid config format, Hash expected, String given')
      end
    end
  end
end