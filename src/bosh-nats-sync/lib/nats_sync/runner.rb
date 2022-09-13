module NATSSync
  class Runner
    include YamlHelper

    def initialize(config_file)
      config = load_yaml_file(config_file)
      NATSSync.config = config
      @bosh_config = config['director']
      @poll_user_sync = config['intervals']['poll_user_sync']
      @nats_config_file_path = config['nats']['config_file_path']
      @nats_server_executable = config['nats']['nats_server_executable']
      @nats_server_pid_file = config['nats']['nats_server_pid_file']
    end

    def run
      NATSSync.logger.info('Nats Sync starting...')
      EM.error_handler { |e| handle_em_error(e) }
      EM.run do
        UsersSync.restart_nats_server(@nats_server_executable, @nats_server_pid_file)
        setup_timers
      end
    end

    def stop
      EM.stop_event_loop
    end

    private

    def setup_timers
      EM.schedule do
        EM.add_periodic_timer(@poll_user_sync) { sync_nats_users }
      end
    end

    def sync_nats_users
      UsersSync.new(@nats_config_file_path, @bosh_config, @nats_server_executable, @nats_server_pid_file).execute_users_sync
    end

    def handle_em_error(err)
      @shutting_down = true
      NATSSync.logger.fatal(err.message.to_s)
      NATSSync.logger.fatal(err.backtrace.join("\n")) if err.respond_to?(:backtrace) && err.backtrace.respond_to?(:join)
      stop
    end
  end
end
