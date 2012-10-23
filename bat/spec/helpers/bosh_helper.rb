# Copyright (c) 2012 VMware, Inc.

require "httpclient"
require "json"
require "net/ssh"
require "zlib"
require "archive/tar/minitar"

require "common/exec"

module BoshHelper
  include Archive::Tar

  # TODO use BOSH_BIN ?
  def bosh(arguments, options={})
    command = "bosh --non-interactive #{arguments} 2>&1"
    puts("--> #{command}") if debug?
    # TODO write to log
    result = Bosh::Exec.sh(command, options)
    yield result if block_given?
    result
  rescue Bosh::Exec::Error => e
    msg = "failed to execute '#{command}':\n#{e.output}"
    raise Bosh::Exec::Error.new(e.status, msg, e.output)
  end

  def bosh_director
    read_environment('BAT_DIRECTOR')
  end

  def password
    read_environment('BAT_VCAP_PASSWORD')
  end

  def debug?
    ENV.has_key?('BAT_DEBUG')
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


  def read_environment(variable)
    if ENV[variable]
      ENV[variable]
    else
      raise "#{variable} not set"
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
    puts "--> ssh: vcap@#{host} '#{command}'" if debug?
    Net::SSH.start(host, user, :password => password, :user_known_hosts_file => %w[/dev/null]) do |ssh|
      output = ssh.exec!(command)
    end
    puts "--> ssh output: '#{output}'" if debug?
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
