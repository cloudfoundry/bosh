# Copyright (c) 2012 VMware, Inc.

require "httpclient"
require "json"
require "net/ssh"
require "zlib"
require "archive/tar/minitar"

require "common/exec"

module BoshHelper
  include Archive::Tar

  def bosh(arguments, options={})
    command = "#{bosh_bin} --non-interactive --config " +
      "#{BH::bosh_cli_config_path} --user admin --password admin " +
      "#{arguments} 2>&1"
    puts("--> #{command}") if debug?
    # TODO write to log
    result = Bosh::Exec.sh(command, options)
    puts(result.output) if verbose?
    yield result if block_given?
    result
  end

  def self.bosh_cli_config_path
    @bosh_cli_config_path
  end

  def self.bosh_cli_config_path=(new_path)
    @bosh_cli_config_path = new_path
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

  def bosh_dns_host
    ENV.has_key?('BAT_DNS_HOST') ? BH.read_environment('BAT_DNS_HOST') : nil
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
    # TODO make user/pass configurable
    @bosh.set_auth(director_url, "admin", "admin")
    @bosh
  end

  def jbosh(path)
    body = http_client.get([director_url, path].join, "application/json").body
    JSON.parse(body)
  end

  def director_url
    "http://#{bosh_director}:25555"
  end

  def info
    jbosh("/info")
  end

  def aws?
    info["cpi"] == "aws"
  end

  def vsphere?
    info["cpi"] == "vsphere"
  end

  def dns?
    info["features"] && info["features"]["dns"]
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

  def ssh(host, user, password, command)
    output = nil
    puts "--> ssh: #{user}@#{host} '#{command}'" if debug?
    Net::SSH.start(host, user, :password => password, :user_known_hosts_file => %w[/dev/null]) do |ssh|
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
