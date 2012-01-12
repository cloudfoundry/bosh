module VCAP::Micro
  class DNS

    # no reverse for now
    FILES = {
      "dnsmasq.conf.erb" => "dnsmasq.conf",
      "dnsmasq.erb" => "dhcp3/dhclient-enter-hooks.d/dnsmasq"
    }

    def initialize(ip, domain)
      @domain = domain
      @ip = ip
    end

    def generate(dest="/etc")
      FILES.each_key do |file|
        src = File.expand_path("config/#{file}")
        dst = "#{dest}/#{FILES[file]}"
        generate_template(src, dst)
      end
      restart
    end

    def generate_template(src, dst)
      erb = ERB.new(template(src), 0, '%<>')
      dir = File.dirname(dst)
      FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
      File.open(dst, 'w') do |f|
        f.write(erb.result(binding))
      end
    end

    def restart
      execute "service dnsmasq restart" do |msg|
        Console.logger.error "failed to restart dnsmasq: #{msg}"
      end
    end

    private

    def template(src)
      File.open(src) do |f|
        f.read
      end
    end

    def execute(cmd)
      result, status = ex(cmd)
      yield result if block_given? && status != 0
    end

    def ex(cmd)
      result = %x[#{cmd} 2>&1]
      [result, $?.exitstatus]
    end
  end
end
