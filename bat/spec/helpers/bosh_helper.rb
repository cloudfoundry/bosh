# Copyright (c) 2012 VMware, Inc.

module BoshHelper

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
    read_environment('BAT_PASSWORD')
  end

  def bat_release_dir
    read_environment('BAT_RELEASE_DIR')
  end

  def stemcell
    read_environment('BAT_STEMCELL')
  end

  # this is a little counter intuitive, but it is better than calling the
  # environment variable BAT_DEPLOYMENT_SPEC_FILE
  def deployment_spec_file
    read_environment('BAT_DEPLOYMENT_SPEC')
  end

  def deployment_spec
    YAML.load_file(deployment_spec_file)
  end

  def debug?
    ENV.has_key?('BAT_DEBUG')
  end

  def bat_release_files
    glob = File.join(bat_release_dir, "dev_releases/bat-*.yml")
    releases = Dir.glob(glob)
    raise "no releases found" if releases.empty?
    releases
  end

  def latest_bat_release
    bat_release_files.last
  end

  def previous_bat_release
    bat_release_files[-2]
  end

  def previous_bat_version
    previous_bat_release.match(/bat-(\d+\.*\d*[-dev]*)/)[1]
  end

  def stemcell_version
    stemcell.match(/bosh-stemcell-\w+-(\d+\.\d+.\d+)/)[1]
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

  def releases
    result = {}
    jbosh("/releases").each {|r| result[r["name"]] = r["versions"] }
    result
  end

  def deployments
    result = {}
    jbosh("/deployments").each {|d| result[d["name"]] = d}
    result
  end

  def stemcells
    jbosh("/stemcells")
  end

  def read_environment(variable)
    if ENV[variable]
      ENV[variable]
    else
      raise "#{variable} not set"
    end
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

RSpec::Matchers.define :succeed_with do |expected|
  match do |actual|
    if actual.exit_status != 0
      false
    elsif expected.instance_of?(String)
      actual.output == expected
    elsif expected.instance_of?(Regexp)
      !!actual.output.match(expected)
    else
      raise ArgumentError, "don't know what to do with a #{expected.class}"
    end
  end
  failure_message_for_should do |actual|
    if expected.instance_of?(Regexp)
      what = "match"
      exp = "/#{expected.source}/"
    else
      what = "be"
      exp = expected
    end
    "expected\n#{actual.output}to #{what}\n#{exp}"
  end
end
