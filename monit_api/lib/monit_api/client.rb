module MonitApi

  TYPES = {
    :file_system => 0,
    :directory => 1,
    :file => 2,
    :process => 3,
    :remote_host => 4,
    :system => 5,
    :fifo => 6
  }

  TYPES_INVERSE = TYPES.invert

  STATUS_MESSAGES = {
    :file_system => "accessible",
    :directory => "accessible",
    :file => "accessible",
    :process => "running",
    :remote_host => "online with all services",
    :system => "running",
    :fifo => "accessible"
  }

  MONITOR = {
    :no => 0,
    :yes => 1,
    :init => 2
  }

  MONITOR_INVERSE = MONITOR.invert

  class Client

    def initialize(uri, options = {})
      @logger = options[:logger] || Logger.new(nil)
      @uri = URI.parse(uri)
    end

    def start(arg)
      service_names(arg).each { |service_name| service_action(service_name, "start") }
    end

    def stop(arg)
      service_names(arg).each { |service_name| service_action(service_name, "stop") }
    end

    def restart(arg)
      service_names(arg).each { |service_name| service_action(service_name, "restart") }
    end

    def monitor(arg)
      service_names(arg).each { |service_name| service_action(service_name, "monitor") }
    end

    def unmonitor(arg)
      service_names(arg).each { |service_name| service_action(service_name, "unmonitor") }
    end

    def status(arg)
      status = get_status
      services = get_services(status, arg)
      result = {}
      services.each do |service|
        type = TYPES_INVERSE[service["type"].to_i]
        status_message = service["status_message"] || STATUS_MESSAGES[type]
        result[service["name"]] = {
          :type => type,
          :status => {
            :code => service["status"].to_i,
            :message => status_message
          },
          :monitor => MONITOR_INVERSE[service["monitor"].to_i],
          :raw => service
        }
      end
      result
    end

    def monit_info
      status = get_status
      monit_status = status["monit"]
      {
        :id => monit_status["id"],
        :incarnation => monit_status["incarnation"],
        :version => monit_status["version"]
      }
    end

    private

    def get_status
      http = Net::HTTP.new(@uri.host, @uri.port)
      request = Net::HTTP::Get.new("/_status2?format=xml")
      request.basic_auth(@uri.user, @uri.password) if @uri.user || @uri.password
      response = http.request(request)
      if response.code != "200"
        raise response.message
      end

      Crack::XML.parse(response.body)
    end

    def service_names(arg)
      status = get_status
      services = get_services(status, arg)
      services.collect { |service| service["name"] }
    end

    def get_services(status, arg)
      services = status["monit"]["services"]["service"]
      services = [services] unless services.kind_of?(Array)

      service_groups_index = {}
      if status["monit"]["servicegroups"]
        groups = status["monit"]["servicegroups"]["servicegroup"]
        groups = [groups] unless groups.kind_of?(Array)
        groups.each do |group|
          service_names = group["service"]
          service_names = [service_names] unless service_names.kind_of?(Array)

          service_names.each do |service_name|
            service_groups_index[service_name] ||= Set.new
            service_groups_index[service_name] << group["name"]
          end
        end
      end

      if arg.kind_of?(Hash)
        if arg.has_key?(:group)
          services = services.select { |service| service_groups_index[service["name"]] &&
              service_groups_index[service["name"]].include?(arg[:group]) }
        end
        services = services.select { |service| service["type"] == TYPES[arg[:type]].to_s } if arg.has_key?(:type)
        services
      elsif arg.kind_of?(String)
        services.select { |service| service["name"] == arg }
      else
        raise ArgumentError
      end
    end

    def service_action(service_name, action)
      @logger.debug("Requesting '#{action}' for #{service_name}")
      http = Net::HTTP.new(@uri.host, @uri.port)
      request = Net::HTTP::Post.new("/#{service_name}")
      request.basic_auth(@uri.user, @uri.password) if @uri.user || @uri.password
      request.content_type = ("application/x-www-form-urlencoded")
      request.body = "action=#{action}"
      response = http.request(request)
      if response.code != "200"
        raise response.message
      end
    end

  end

end
