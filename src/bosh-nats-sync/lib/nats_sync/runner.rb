require 'rufus-scheduler'

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

      @scheduler = Rufus::Scheduler.new
    end

    def run
      NATSSync.logger.info('Nats Sync starting...')

      UsersSync.reload_nats_server_config(@nats_server_executable, @nats_server_pid_file)

      # Rufus Scheduler does not have a way to inject an error handler, and in fact recommends
      # in the readme to redefine the on_error method if you need custom behavior.
      def @scheduler.on_error(job, err)
        NATSSync.logger.fatal(err.message.to_s)
        NATSSync.logger.fatal(err.backtrace.join("\n")) if err.respond_to?(:backtrace) && err.backtrace.respond_to?(:join)
        shutdown
      end

      @scheduler.interval "#{@poll_user_sync}s" do
        sync_nats_users
      end

      @scheduler.join
    end

    def stop
      @scheduler.shutdown
    end

    private

    def sync_nats_users
      UsersSync.new(@nats_config_file_path, @bosh_config, @nats_server_executable, @nats_server_pid_file).execute_users_sync
    end
  end
end
