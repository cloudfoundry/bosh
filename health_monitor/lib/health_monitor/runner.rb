module Bosh::HealthMonitor
  class Runner
    include YamlHelper

    def self.run(config_file)
      new(config_file).run
    end

    def initialize(config_file)
      Bhm.config = default_config #.merge(load_yaml_file(config_file))

      @logger    = Bhm.logger
      @director  = Bhm.director
      @intervals = Bhm.intervals
      @mbus      = Bhm.mbus

      # Things to manage:
      @deployment_manager = DeploymentManager.new
      @agent_manager      = AgentManager.new
    end

    # TBD: extract to config file if tests feel it is natural there
    def default_config
      {
        "director" => {
          "endpoint" => "http://172.31.113.142:25555",
          "user"     => "admin",
          "password" => "admin"
        },

        "mbus" => {
          "endpoint" => "nats://172.31.113.142:4222",
          "user"     => "bosh",
          "password" => "b0$H"
        },

        "intervals" => { # All intervals are in seconds
          "poll_director" => 60,
          "log_stats"     => 60,
          "poll_agents"   => 10,
          "agent_timeout" => 60
        }
      }
    end

    def run
      EM.kqueue; EM.epoll

      EM.error_handler do |e|
        @logger.error "EM error: #{e}"
        # @logger.error("#{e.backtrace.join("\n")}")
      end

      EM.run do
        connect_to_mbus
        @agent_manager.setup_subscriptions
        setup_timers
        @logger.info "Bosh HealthMonitor #{Bhm::VERSION} is running..."
      end
    end

    def setup_timers
      EM.next_tick do
        poll_director

        EM.add_periodic_timer(@intervals.poll_director) { poll_director }
        EM.add_periodic_timer(@intervals.poll_agents) { poll_agents }
        EM.add_periodic_timer(@intervals.log_stats) { log_stats }
      end
    end

    def log_stats
      @logger.info("Managing %s, %s" % [ pluralize(@deployment_manager.deployments_count, "deployment"), pluralize(@agent_manager.agents_count, "agent") ])
      @logger.info("Agent requests sent = %s, replies received = %s" % [ @agent_manager.requests_sent, @agent_manager.replies_received ])
    end

    def connect_to_mbus
      NATS.on_error do |e|
        if e.kind_of? NATS::ConnectError
          @logger.fatal("NATS connection failed: #{e}")
          exit(1)
        else
          @logger.error("NATS problem, #{e}")
        end
      end

      nats_client_options = {
        :uri       => @mbus.endpoint,
        :user      => @mbus.user,
        :pass      => @mbus.password,
        :autostart => false
      }

      Bhm.nats = NATS.connect(nats_client_options) do
        @logger.info("Connected to NATS at `#{@mbus.endpoint}'")
      end
    end

    def poll_director
      @logger.debug "Getting deployments from director..."
      Fiber.new {
        deployments = @director.get_deployments

        deployments.each do |deployment|
          deployment_name = deployment["name"]

          @logger.info "Found deployment `#{deployment_name}'"

          deployment_info = @director.get_deployment(deployment_name)
          @logger.debug "Updated deployment information for `#{deployment_name}'"

          @deployment_manager.update_deployment(deployment_name, deployment_info)
          # TODO: handle missing deployments

          if deployment_info["vms"].kind_of?(Array)
            deployment_info["vms"].each do |vm|
              @agent_manager.update_agent(deployment_name, vm["agent_id"])
              # TODO: handle missing agents
            end
          else
            @logger.warn "Cannot get VMs list from deployment, possibly the old director version"
          end
        end
      }.resume
    end

    def poll_agents
      @logger.debug "Polling agents..."

      @agent_manager.each_agent do |agent|
        @agent_manager.update_state(agent)
      end
    end

  end
end
