# Copyright (c) 2012 VMware, Inc.

module BoshHelper

  # TODO use BOSH_BIN ?
  def bosh(arguments, options={})
    options[:on_error] = :return unless options[:on_error]
    command = "bosh --non-interactive #{arguments} 2>&1"
    # TODO write to log
    result = Bosh::Exec.sh(command, options)
    yield result.output if block_given?
    result
  end

  def bosh!(arguments)
    result = bosh(arguments)
    unless result.exit_status == 0
      raise "bosh execution failure of: #{result.command}\n#{result.output}"
    end
  end

  def bosh_director
    read_environment('BAT_DIRECTOR')
  end

  def bat_release_dir
    read_environment('BAT_RELEASE_DIR')
  end

  def stemcell
    read_environment('BAT_STEMCELL')
  end

  def deployment
    read_environment('BAT_DEPLOYMENT')
  end

  def bat_release_files
    glob = File.join(bat_release_dir, "dev_releases/bat-*.yml")
    Dir.glob(glob)
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
    json = http_client.get([director_url, path].join, "application/json").body
    JSON.parse(json)
  end

  def director_url
    "http://#{bosh_director}:25555"
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