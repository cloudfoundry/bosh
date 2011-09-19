require 'netaddr'
require 'socket'
require 'resolv'
require 'statemachine'
require 'timeout'

module VCAP
  module Micro
    class Network
      attr_accessor :type

      A_ROOT_SERVER = '198.41.0.4'

      def self.local_ip(route = A_ROOT_SERVER)
        retries ||= 0
        route ||= A_ROOT_SERVER
        orig, Socket.do_not_reverse_lookup = Socket.do_not_reverse_lookup, true
        UDPSocket.open {|s| s.connect(route, 1); s.addr.last }
      rescue Errno::ENETUNREACH
        # happens on boot when dhcp hasn't completed when we get here
        sleep 3
        retries += 1
        retry if retries < 3
      ensure
        Socket.do_not_reverse_lookup = orig
      end

      def self.gateway
        %x{netstat -rn 2>&1}.split("\n").each do |line|
          fields = line.split(/\s+/)
          if fields[0] =~ /^default|0\.0\.0\.0$/
            return fields[1]
          end
        end
        nil
      end

      def self.ping(host, count=3)
        %x{ping -c #{count} #{host} > /dev/null 2>&1}
        $? == 0
      end

      # create a class variable?
      def self.ext_lookup(name)
        Network.resolv_guard do
          Resolv::DNS.open(:nameserver => ['208.78.70.9']) do |dns|
            dns.getaddress(name)
          end
        end
      end

      def self.lookup(name)
        Network.resolv_guard(name) do
          Resolv.getaddress(name)
        end
      end

      def self.reverse_lookup(ip)
        Network.resolv_guard(ip) do
          Resolv.getname(ip)
        end
      end

      def self.resolv_guard(query)
        yield
      rescue Errno::ENETUNREACH => e
        Console.logger.error("network unreachable for #{query}: #{e.message}")
        nil
      rescue Resolv::ResolvError => e
        Console.logger.error("failed to resolve #{query}: #{e.message}")
        nil
      end

      def initialize
        @logger = Console.logger
        @state = Statemachine.build do
          state :unconfigured do
            event :start, :starting
            event :fail, :failed
          end
          state :starting do
            event :timeout, :failed
            event :fail, :failed
            event :started, :up
          end
          state :failed do
            event :restart, :starting
          end
          state :up do
            event :connection_lost, :offline
            event :restart, :starting
          end
          state :offline do
            event :recovered, :up
            event :restart, :starting
          end
        end
        @previous = nil

        if dhcp?
          @type = :dhcp
        else
          @type = :static
        end
        @state.start
        restart_with_timeout
      end

      def up?
        @state.state == :up
      end

      def starting?
        @state.state == :starting
      end

      def failed?
        @state.state == :failed
      end

      def offline?
        @state.state == :offline
      end

      def status
        @state.state
      end

      def connection_lost
        $stderr.puts "\nnetwork connectivity lost :-("
        @state.connection_lost
        @previous = @state.state
      end

      # async
      def restart
        # warn unless it is the first time we run, i.e. no previous state
        if starting? && @previous
          $stderr.puts("network already restarting".red)
          @logger.error("network already restarting: #{caller.join("\n")}")
          return
        end
        @state.restart
        Thread.new do
          restart_with_timeout
        end
      end

      def restart_with_timeout
        Timeout::timeout(10) do
          out = `service network-interface stop INTERFACE=eth0 2>&1`
          # ignoring failures on stop
          out = `service network-interface start INTERFACE=eth0 2>&1`
          unless $? == 0
            @state.timeout
          end
        end
        $stderr.puts "network connectivity regained :-)" if @previous == :offline
        @state.started
      rescue Timeout::Error
        @state.timeout
      ensure
        @previous = @state.state
      end

      INTERFACES = "/etc/network/interfaces"
      def dhcp?
        if File.exist?(INTERFACES)
          File.open(INTERFACES) do |f|
            f.readlines.each do |line|
              return true if line.match(/^iface eth0 inet dhcp$/)
            end
          end
        end
        false
      end

      def dhcp
        previous = @type
        @type = :dhcp
        write_network_interfaces(BASE_TEMPLATE + DHCP_TEMPLATE, nil)
        # no need to restart if we already are running dhcp
        restart unless @type == previous
      end

      def static(net)
        @type = :static
        @state.restart
        cidr_ip_mask = "#{net['address']} #{net['netmask']}"

        net_cidr = NetAddr::CIDR.create(cidr_ip_mask)
        net['network'] = net_cidr.network
        net['broadcast'] = net_cidr.broadcast

        write_network_interfaces(BASE_TEMPLATE + MANUAL_TEMPLATE, net)

        if net['dns']
          dns(net['dns'])
        end
        restart
      rescue NetAddr::ValidationError => e
        puts("invalid network: #{cidr_ip_mask}")
        @state.fail
      end

      RESOLV_CONF = "/etc/resolv.conf"
      # Comma separated list of dns servers
      def dns(dns_string)
        servers = dns_string.split(/,/).map { |s| s.gsub(/\s+/, '') }
        File.open(RESOLV_CONF, 'w') do |f|
          servers.each do |s|
            f.puts("nameserver #{s}")
          end
        end
      end

      def write_network_interfaces(template_data, net)
        FileUtils.mkdir_p(File.dirname(INTERFACES))

        template = ERB.new(template_data, 0, '%<>')
        result = template.result(binding)
        File.open(INTERFACES, 'w') do |fh|
          fh.write(result)
        end
      end

      BASE_TEMPLATE =<<TEMPLATE
auto lo
iface lo inet loopback

TEMPLATE

      DHCP_TEMPLATE = <<TEMPLATE
auto eth0
iface eth0 inet dhcp
TEMPLATE

      MANUAL_TEMPLATE = <<TEMPLATE
auto eth0
iface eth0 inet static
address <%= net["address"]%>
network <%= net["network"] %>
netmask <%= net["netmask"]%>
broadcast <%= net["broadcast"] %>
gateway <%= net["gateway"] %>
TEMPLATE

    end
  end
end
