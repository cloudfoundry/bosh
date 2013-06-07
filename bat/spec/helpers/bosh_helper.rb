# Copyright (c) 2012 VMware, Inc.

require "httpclient"
require "json"
require "net/ssh"
require "zlib"
require "archive/tar/minitar"

require "common/exec"

module BoshHelper
  include Archive::Tar

  DEFAULT_POLL_INTERVAL = 1

  def bosh(arguments, options={})
    poll_interval = options[:poll_interval] || DEFAULT_POLL_INTERVAL
    command = "#{bosh_bin} --non-interactive " +
      "-P #{poll_interval} " +
      "--config #{BH::bosh_cli_config_path} " +
      "--user admin --password admin " +
      "#{arguments} 2>&1"
    puts("--> #{command}") if debug?
    # TODO write to log
    begin
      result = Bosh::Exec.sh(command, options)
    rescue Bosh::Exec::Error => e
      puts("Bosh command failed: #{e.output}")
      raise
    end
    puts(result.output) if verbose?
    yield result if block_given?
    result
  end

  def get_vms
    output = bosh("vms --details").output
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

  def wait_for_vm(name)
    5.times do
      vm = get_vms.detect { |v| v[:job_index] == name }
      return vm if vm
    end
    nil
  end

  def self.bosh_cli_config_path
    @bosh_cli_config_tempfile ||= Tempfile.new("bosh_config")
    @bosh_cli_config_tempfile.path
  end

  def self.delete_bosh_cli_config
    @bosh_cli_config_tempfile.delete if @bosh_cli_config_tempfile
  end

  def bosh_bin
    BH.read_environment('BAT_BOSH_BIN', 'bundle exec bosh')
  end

  def bosh_director
    BH.read_environment('BAT_DIRECTOR')
  end

  def password
    BH.read_environment('BAT_VCAP_PASSWORD')
  end

  def private_key
    ENV['BAT_VCAP_PRIVATE_KEY']
  end

  def ssh_options
    {
        private_key: private_key,
        password: password
    }
  end

  def bosh_dns_host
    ENV['BAT_DNS_HOST']
  end

  def debug?
    ENV.has_key?('BAT_DEBUG')
  end

  def verbose?
    ENV["BAT_DEBUG"] == "verbose"
  end

  def fast?
    ENV.has_key?('BAT_FAST')
  end

  def http_client
    return @bosh if @bosh
    @bosh = HTTPClient.new
    @bosh.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
    # TODO make user/pass configurable
    @bosh.set_auth(director_url, "admin", "admin")
    @bosh
  end

  def jbosh(path)
    body = http_client.get([director_url, path].join, "application/json").body
    JSON.parse(body)
  end

  def director_url
    "https://#{bosh_director}:25555"
  end

  def info
    jbosh("/info")
  end

  def aws?
    info["cpi"] == "aws"
  end

  def openstack?
    info["cpi"] == "openstack"
  end

  def vsphere?
    info["cpi"] == "vsphere"
  end

  def compiled_package_cache?
    info["features"] && info["features"]["compiled_package_cache"]
  end

  def dns?
    info["features"] && info["features"]["dns"]
  end

  def bosh_tld
    info["features"]["dns"]["extras"]["domain_name"] if dns?
  end

  def tasks_processing?
    # `bosh tasks` exit code is 1 if no tasks running
    bosh("tasks", :on_error => :return).output =~ /\| processing \|/
  end

  def self.read_environment(variable, default=nil)
    ENV.fetch(variable) do |v|
      return default if default
      raise "#{v} not set"
    end
  end

  def persistent_disk(host)
    disks = get_json("http://#{host}:4567/disks")
    disks.each do |disk|
      values = disk.last
      if disk.last["mountpoint"] == "/var/vcap/store"
        return values["blocks"]
      end
    end
  end

  # this method will retry a bunch of times, as when it is used to
  # get json from a new batarang job, it may not have started when
  # it we call it
  def get_json(url, max_times=120)
    client = HTTPClient.new
    tries = 0
    begin
      body = client.get(url, "application/json").body
    rescue Errno::ECONNREFUSED => e
      raise e if tries == max_times
      sleep(1)
      tries += 1
      retry
    end

    JSON.parse(body)
  end

  def ssh(host, user, command, options = {})
    options = options.dup
    output = nil
    puts "--> ssh: #{user}@#{host} '#{command}'" if debug?

    private_key = options.delete(:private_key)
    options[:user_known_hosts_file] = %w[/dev/null]
    options[:keys] = [private_key] unless private_key.nil?

    if options[:keys].nil? && options[:password].nil?
      raise "need to set ssh :password, :keys, or :private_key"
    end

    Net::SSH.start(host, user, options) do |ssh|
      output = ssh.exec!(command)
    end

    puts "--> ssh output: '#{output}'" if verbose?
    output
  end

  def tarfile
    Dir.glob("*.tgz").first
  end

  def tar_contents(tgz)
    list = []
    tar = Zlib::GzipReader.open(tgz)
    Minitar.open(tar).each do |entry|
      list << entry.name if entry.file?
    end
    list
  end
end
