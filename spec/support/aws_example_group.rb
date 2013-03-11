require 'tempfile'

module AwsSystemExampleGroup
  def vpc_outfile_path
    "#{spec_tmp_path}/aws_vpc_receipt.yml"
  end

  def vpc_outfile
    YAML.load_file vpc_outfile_path
  end

  def route53_outfile_path
    "#{spec_tmp_path}/aws_route53_receipt.yml"
  end
  
  def rds_outfile_path
    "#{spec_tmp_path}/aws_rds_receipt.yml"
  end

  def microbosh_ip
    vpc_outfile["elastic_ips"]["bosh"]["ips"][0]
  end

  def bosh_config_path
    @bosh_config_path ||= Tempfile.new("bosh_config").path
  end

  def latest_micro_bosh_stemcell
    raise "set CI_PASSWORD and CI_SERVER environment variables to retrieve stemcell ami id" unless ENV['CI_PASSWORD'] && ENV['CI_SERVER']
    `curl -sk https://ci:#{ENV['CI_PASSWORD']}@#{ENV['CI_SERVER']}/job/aws_micro_bosh_stemcell/lastSuccessfulBuild/artifact/stemcell-ami.txt`
  end

  def latest_stemcell_path
    raise "set CI_PASSWORD and CI_SERVER environment variables to retrieve stemcell ami id" unless ENV['CI_PASSWORD'] && ENV['CI_SERVER']
    build_data = JSON.parse(`curl -sk https://ci:#{ENV['CI_PASSWORD']}@#{ENV['CI_SERVER']}/job/aws_bosh_stemcell/lastSuccessfulBuild/api/json`)
    stemcell = build_data['artifacts'].map { |f| f['fileName'] }.detect { |f| f =~ /light/ }
    dir = Dir.mktmpdir
    Dir.chdir(dir) do
      `curl -skO https://ci:#{ENV['CI_PASSWORD']}@bosh-jenkins.cf-app.com/job/aws_bosh_stemcell/lastSuccessfulBuild/artifact/#{stemcell}`
    end
    "#{dir}/#{stemcell}"
  end

  def stemcell_version(stemcell_path)
    Dir.mktmpdir do |dir|
      %x{tar xzf #{stemcell_path} --directory=#{dir} stemcell.MF} || raise("Failed to untar stemcell")
      stemcell_manifest = "#{dir}/stemcell.MF"
      st = YAML.load_file(stemcell_manifest)
      p st
      st["version"]
    end
  end

  def spec_tmp_path
    File.join(BOSH_TMP_DIR, "spec")
  end

  def deployments_path
    File.join(BOSH_TMP_DIR, "spec", "deployments")
  end

  def micro_deployment_path
    File.join(deployments_path, "micro")
  end

  def bat_deployment_path
    File.join(deployments_path, "bat")
  end

  def aws_configuration_template_path
    "#{ASSETS_DIR}/aws/aws_configuration_template.yml.erb"
  end

  def run(cmd, options = {})
    Bundler.with_clean_env do
      lines = []
      IO.popen(cmd).each do |line|
        puts line.chomp
        lines << line.chomp
      end.close # force the process to close so that $? is set
      if options[:last_number]
        line_number = options[:last_number]
        line_number = lines.size if lines.size < options[:last_number]
        cmd_out = lines[-line_number..-1].join("\n")
      else
        cmd_out = lines.join("\n")
      end

      unless $?.success?
        err_msg = "Failed: '#{cmd}' from #{Dir.pwd}, with exit status #{$?.to_i}\n\n #{cmd_out}"

        if options[:ignore_failures]
          puts("#{err_msg}, continuing anyway")
        else
          raise(err_msg)
        end
      end
      cmd_out
    end
  end

  def run_bosh(cmd, options = {})
    debug_on_fail = options.fetch(:debug_on_fail, false)
    options.delete(:debug_on_fail)
    @run_bosh_failures ||= 0
    run "#{binstubs_path}/bosh -v -n -P 10 --config '#{bosh_config_path}' #{cmd}", options
  rescue
    @run_bosh_failures += 1
    if @run_bosh_failures == 1 && debug_on_fail
      # get the debug log, but only for the first failure, in case "bosh task last"
      # fails - or we'll end up in an endless loop
      run_bosh "task last --debug", {:last_number => 100}
      @run_bosh_failures = 0
    end
    raise
  end

  def binstubs_path
    @binstubs_path ||= begin
      path = File.join(BOSH_TMP_DIR, "spec", "bin")
      run "rm -rf '#{path}'"
      FileUtils.mkdir_p path
      Dir.chdir(BOSH_ROOT_DIR) do
        run "bundle install --binstubs='#{path}' --local"
      end
      path
    end
  end

  def deployments_path
    File.join(BOSH_TMP_DIR, "spec", "deployments")
  end

  def copy_keys(global_path, local_path)
    global_private_key_path = global_path.gsub(/\.pub$/, '')
    global_public_key_path = "#{global_private_key_path}.pub"

    local_private_key_path = local_path.gsub(/\.pub$/, '')
    local_public_key_path = "#{local_private_key_path}.pub"

    FileUtils.cp global_private_key_path, local_private_key_path
    FileUtils.cp global_public_key_path, local_public_key_path
  end

  def self.included(base)
    base.before(:each) do
      ENV['BOSH_KEY_PAIR_NAME'] ||= "bosh"
      ENV['BOSH_KEY_PATH'] ||= "/tmp/id_rsa_bosh"

      if ENV['GLOBAL_BOSH_KEY_PATH'] && File.exist?(ENV['GLOBAL_BOSH_KEY_PATH'])
        copy_keys ENV['GLOBAL_BOSH_KEY_PATH'], ENV['BOSH_KEY_PATH']
      end

      FileUtils.rm_rf deployments_path
      FileUtils.mkdir_p micro_deployment_path

      run_bosh "aws destroy"

      FileUtils.rm_rf("#{ASSETS_DIR}/aws/create-*-output-*.yml")
      FileUtils.rm_rf(vpc_outfile_path)
      FileUtils.rm_rf(rds_outfile_path) if File.exists?(rds_outfile_path)
    end
  end
end
