require 'tempfile'

module AwsSystemExampleGroup
  def vpc_outfile_path
    `ls #{ASSETS_DIR}/aws/aws_vpc_receipt.yml`.strip
  end

  def vpc_outfile
    YAML.load_file vpc_outfile_path
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

      cmd_out = lines.join("\n")
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
    run "#{binstubs_path}/bosh -v -n --config '#{bosh_config_path}' #{cmd}", options
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

  def self.included(base)
    base.before(:each) do
      ENV['BOSH_KEY_PAIR_NAME'] = "bosh"
      ENV['BOSH_KEY_PATH'] = "/tmp/id_rsa_bosh"

      FileUtils.rm_rf deployments_path
      FileUtils.mkdir_p micro_deployment_path
      FileUtils.mkdir_p bat_deployment_path

      if ENV["NO_PROVISION"]
        puts "Not deleting and recreating AWS resources, assuming we already have them"
      else
        puts "Using configuration template: #{aws_configuration_template_path}"
        run_bosh "aws destroy '#{aws_configuration_template_path}'"
        puts "CLEANUP SUCCESSFUL"

        system "rm -f #{ASSETS_DIR}/aws/create-*-output-*.yml"
        system "rm -f #{ASSETS_DIR}/aws/aws_vpc_receipt.yml"

        run_bosh "aws create vpc '#{aws_configuration_template_path}'"

        puts "AWS RESOURCES CREATED SUCCESSFULLY!"
      end
    end
  end
end
