require 'httpclient'
require 'json'
require 'net/ssh'
require 'zlib'
require 'archive/tar/minitar'
require 'tempfile'
require 'common/exec'

module Bat
  module BoshHelper
    include Archive::Tar

    def bosh(*args, &blk)
      @bosh_runner.bosh(*args, &blk)
    end

    def bosh_safe(*args, &blk)
      @bosh_runner.bosh_safe(*args, &blk)
    end

    def ssh_options
      {
        private_key: ENV['BAT_VCAP_PRIVATE_KEY'],
        password: @env.vcap_password
      }
    end

    def bosh_dns_host
      ENV['BAT_DNS_HOST']
    end

    def aws?
      @bosh_api.info['cpi'] == 'aws'
    end

    def openstack?
      @bosh_api.info['cpi'] == 'openstack'
    end

    def dns?
      info = @bosh_api.info
      info['features'] && info['features']['dns']
    end

    def bosh_tld
      info = @bosh_api.info
      info['features']['dns']['extras']['domain_name'] if dns?
    end

    def persistent_disk(host)
      disks = get_json("http://#{host}:4567/disks")
      disks.each do |disk|
        values = disk.last
        if disk.last['mountpoint'] == '/var/vcap/store'
          return values['blocks']
        end
      end
    end

    def ssh(host, user, command, options = {})
      options = options.dup
      output = nil
      puts "--> ssh: #{user}@#{host} '#{command}'"

      private_key = options.delete(:private_key)
      options[:user_known_hosts_file] = %w[/dev/null]
      options[:keys] = [private_key] unless private_key.nil?

      if options[:keys].nil? && options[:password].nil?
        raise 'need to set ssh :password, :keys, or :private_key'
      end

      @logger.info("SSH host=#{host} user=#{user} options=#{options.inspect}")

      Net::SSH.start(host, user, options) do |ssh|
        output = ssh.exec!(command)
      end

      puts "--> ssh output: '#{output}'"
      output
    end

    def tarfile
      Dir.glob('*.tgz').first
    end

    def tar_contents(tgz, entries = false)
      list = []
      tar = Zlib::GzipReader.open(tgz)
      Minitar.open(tar).each do |entry|
        is_file = entry.file?
        entry = entry.name unless entries
        list << entry if is_file
      end
      list
    end

    def wait_for_vm(name)
      @logger.info("Start waiting for vm #{name}")
      vm = nil
      5.times do
        vm = get_vms.find { |v| v[:job_index] == name }
        break if vm
      end
      @logger.info("Finished waiting for vm #{name} vm=#{vm.inspect}")
      vm
    end

    private

    def get_vms
      output = @bosh_runner.bosh('vms --details').output
      table = output.lines.grep(/\|/)

      table = table.map { |line| line.split('|').map(&:strip).reject(&:empty?) }
      headers = table.shift || []
      headers.map! do |header|
        header.downcase.tr('/ ', '_').to_sym
      end
      output = []
      table.each do |row|
        output << Hash[headers.zip(row)]
      end
      output
    end

    # this method will retry a bunch of times, as when it is used to
    # get json from a new batarang job, it may not have started when
    # it we call it
    def get_json(url, max_times = 120)
      client = HTTPClient.new
      tries = 0
      begin
        body = client.get(url, 'application/json').body
      rescue Errno::ECONNREFUSED => e
        raise e if tries == max_times
        sleep(1)
        tries += 1
        retry
      end

      JSON.parse(body)
    end
  end
end
