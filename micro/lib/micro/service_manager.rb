module VCAP::Micro
  class ServiceManager

    SERVICE_GROUPS = "/var/vcap/jobs/micro/config/monit.yml"
    def initialize
      @logger = Console.logger
    end

    def monit_status
      Bosh::Agent::Monit.retry_monit_request do |client|
        client.status(:group => Bosh::Agent::BOSH_APP_GROUP)
      end
    end

    def status_summary
      status = monit_status
      return "unknown" unless status
      status.each do |name, data|
          return "failed".red if data && data[:status][:message] != "running"
      end
      "ok".green
    end

    def service_groups
      @groups ||= YAML.load_file(SERVICE_GROUPS)
    rescue Errno::ENOENT
      @groups = nil
    end

    def group_status(group)
      if enabled?(group)
        monit = monit_status
        ok = true
        service_groups[group].each do |service|
          data = monit[service]
          @logger.debug("#{service} = #{data.inspect}")
          ok = false unless data && data[:status][:message] == "running"
        end
        ok ? :ok : :failed
      else
        :disabled
      end
    end

    def status(group)
      enabled?(group) ? "enabled" : "disabled"
    end

    def enabled?(group)
      File.exist?(monitrc(group))
    end

    def enable!(group)
      FileUtils.mv(disabled(group), monitrc(group))
      Bosh::Agent::Monit.reload
      Bosh::Agent::Monit.start_services(60)
    end

    def disable!(group)
      FileUtils.mv(monitrc(group), disabled(group))
      service_groups[group].each do |service|
        puts "disabling #{service}"
        %x{monit stop #{service}}
      end
      Bosh::Agent::Monit.reload
      Bosh::Agent::Monit.start_services(60)
    end

    def toggle(group)
      enabled?(group) ? disable!(group) : enable!(group)
    end
    def clear
      print "\e[H\e[2J"
    end

    def press_return_to_continue
      ask("Press return to continue ")
    end

    def service_header
      say("Micro Cloud Foundry services status:\n\n")
      service_groups.each do |group, services|
        case group_status(group)
        when :ok
          printf(" %-25s %s\n", group, "ok".green)
        when :disabled
          printf(" %-25s %s\n", group, "disabled".yellow)
        when :failed
          printf(" %-25s %s\n", group, "failed".red)
          services.each do |service|
            status = monit_status
            data = status[service]
            s = if data && data[:status]
              data[:status][:message]
            else
              @logger.warn("unknown service state for #{service}: #{data.inspect}")
              "unknown"
            end
            s = data && data[:status] ? data[:status][:message] : "unknown"
            printf("   %-23s %s\n", service, s == "running" ? s.green : s.red)
          end
        else
          printf(" %-25s %s\n", group, "unknown".yellow)
        end
      end
      puts("\n")
    end

    def service_menu
      while true
        clear
        service_header

        choose do |menu|
          menu.prompt = "\nSelect option: "
          menu.select_by = :index
          menu.choice("refresh service status") { }
          service_groups.each do |group, services|
            next if group == "core"
            menu.choice("#{enabled?(group) ? 'disable' : 'enable'} #{group}") { toggle(group) }
          end
          menu.choice("return to main menu") { return }
        end
      end
    end

    def monitrc(group)
      "/var/vcap/monit/#{group}.monitrc"
    end

    def disabled(group)
      "/var/vcap/monit/#{group}.disabled"
    end
  end

end
