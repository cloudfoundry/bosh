require 'yaml'
require 'fileutils'

# Keep our state in a seperate class so that we don't pollute the
# global environment
class BoshBvtEnv

  DEFAULT_BOSH_USER       = "admin"
  DEFAULT_BOSH_PASSWORD   = "admin"
  DEFAULT_BOSH_DEV_NAME   = "bvt_bosh"

  # The following are all relative to the test dir root.
  DEFAULT_VCAP_DIR        = "../../vcap"
  DEFAULT_SERVICES_DIR    = "../../vcap/services"
  DEFAULT_RELEASE_DIR     = "../../release"
  DEFAULT_DEPLOYMENTS_DIR = "../../deployments"
  DEFAULT_ARTIFACTS_DIR   = "../../ci-artifacts-dir"
  DEFAULT_BOSH_DIR        = "../../bosh"
  DEFAULT_BOSH_MANIFEST   = "Please_set_bosh_manifest"

  attr_reader :root_dir, :release_dir, :config_dir, :director_url,
              :manifest_src, :manifest_file, :vcap_dir, :services_dir,
              :release_config, :bosh_user, :bosh_password, :bosh_dev_name,
              :artifacts_dir, :bosh_dir, :bvt_bosh_config_file

  def initialize
    # Root dir will be the tests dir (parent of rakelib)
    @root_dir        = File.expand_path("..", File.dirname(__FILE__))
    @config_dir      = File.expand_path("config", @root_dir)

    # Pull in all property values from yml file, defaulting values when missing
    @bvt_bosh_config_file = ENV['BVT_BOSH_CONFIG_FILE'] || File.join(@config_dir, "bvt_bosh.yml")
    @config = YAML::load(File.open(@bvt_bosh_config_file))
    @release_dir     = File.expand_path(@config['release_dir'] || DEFAULT_RELEASE_DIR, @root_dir)
    @deployments_dir = File.expand_path(@config['deployments_dir'] || DEFAULT_DEPLOYMENTS_DIR)
    @vcap_dir        = File.expand_path(@config['vcap_dir'] || DEFAULT_VCAP_DIR, @root_dir)
    @services_dir    = File.expand_path(@config['services_dir'] || DEFAULT_SERVICES_DIR, @root_dir)
    @artifacts_dir   = ENV['ARTIFACTS_DIR'] || File.expand_path(@config['artifacts_dir'] || DEFAULT_ARTIFACTS_DIR, @root_dir)
    @bosh_dir        = File.expand_path(@config['bosh_dir'] || DEFAULT_BOSH_DIR, @root_dir)

    @director_url    = ENV['DIRECTOR_URL'] || @config['director_url']
    @bosh_user       = @config['bosh_user'] || DEFAULT_BOSH_USER
    @bosh_password   = @config['bosh_password'] || DEFAULT_BOSH_PASSWORD
    @bosh_dev_name   = @config['bosh_dev_name'] || DEFAULT_BOSH_DEV_NAME
    @bosh_manifest   = @config['bosh_manifest'] || DEFAULT_BOSH_MANIFEST
    @manifest_src    = File.expand_path("#{@deployments_dir}/#{@bosh_manifest}", @root_dir)
    unless File.directory?(@artifacts_dir)
      Dir.mkdir(@artifacts_dir)
    end
    @manifest_file   = File.open("#{@artifacts_dir}/bvt_bosh_manifest.yml","w")
  end
end

namespace :ci_bosh do
  bosh_env = BoshBvtEnv.new

  desc "Set BOSH target"
  task :target do
    unless bosh_env.director_url
      fail "Please set director_url in #{bvt_bosh_config_file}"
    end
    url = bosh_env.director_url
    puts "Setting BOSH target to #{url}"
    result = `bosh --no-color --non-interactive target #{url}`
    unless /Target set to '.* \(#{url}\)'/.match(result)
      fail "Cloud not set bosh target. Result: #{result}"
    end
  end

  desc "Login to BOSH"
  task :login => [:target] do
    puts "Logging into BOSH as '#{bosh_env.bosh_user}'"
    result = `bosh login #{bosh_env.bosh_user} #{bosh_env.bosh_password}`
    unless /Logged in as '#{bosh_env.bosh_user}'/.match(result)
      fail "Could not login to bosh. Result: #{result}"
    end
  end

  desc "Set BOSH deployment"
  task :deployment do
    man = bosh_env.manifest_file.path
    puts "Setting BOSH deployment"
    result = `bosh deployment #{man}`
    unless /Deployment set to .*/.match(result)
      fail "Could not set bosh deployment. Result: #{result}"
    end
  end

  desc "Checkout release"
  task :checkout_release do
    puts "Checking out release"
    unless File.directory?(bosh_env.release_dir)
      fail "release directory does not exist."
    end
    Dir.chdir(bosh_env.release_dir) do
      system "git pull"
    end
  end

  desc "Update core"
  task :update_core do
    puts "Updating core"
    Dir.chdir(bosh_env.release_dir) do
      # TODO: add ability to do selectively do official submodule
      # update or release right from HEAD of real core
      FileUtils::rm_rf("src/core")
      FileUtils::ln_s(bosh_env.vcap_dir, "src/core")
    end
  end

  desc "Update services"
  task :update_services do
    puts "Updating services"
    Dir.chdir(bosh_env.release_dir) do
      # TODO: add ability to do selectively do official submodule
      # update or release right from HEAD of real core
      FileUtils::rm_rf("src/services")
      FileUtils::ln_s(bosh_env.services_dir, "src/services")
    end
  end

  desc "Clean releases"
  task "clean_releases" do
    puts "Cleaning local versions of releases"
    Dir.chdir(bosh_env.release_dir) do
      `bosh reset`
    end
  end

  # Removed these tasks as dependencies of create_release, in case we know
  # we've already got the release directory hierarchy in the desired state.
  desc "prepare the release directory tree"
  task :prep_release_dir => [:checkout_release, :clean_releases,
                             :update_core, :update_services] do; end

  desc "Create release <fail_if_unchanged default=true>"
  task :create_release, :fail_if_unchanged do | t, args |
    fail_if_unchanged = args[:fail_if_unchanged] || "true"
    puts "Creating release under #{bosh_env.release_dir}"
    result = ""
    Dir.chdir(bosh_env.release_dir) do
      if File.exists?("config/dev.yml") && File.exists?("dev_releases")
        initial_config = YAML.load_file("config/dev.yml")
        result = `bosh create release --force`
      else
        puts "no config/dev.yml found, so setting dev_name=#{bosh_env.bosh_dev_name} in stdin..."
        f = Tempfile.open("bosh_create_input.txt")
        f.write("#{bosh_env.bosh_dev_name}\n")
        f.close
        result = `bosh create release --force <#{f.path}`
      end
    end
    # IMPROVE_ME: when a distinct "already exists" return code
    #    is available from create release, use that.
    if result.include?("version is no different from")
      if fail_if_unchanged[0] == "t"
        fail "bosh create release did not generate a new release; no different from predecessor"
      else
        puts "  warning: create release indicates release unchanged"
      end
    end
    unless result.include?("Release manifest saved in")
       fail "bosh create release failed: #{result}"
    end
  end

  desc "Upload latest release, <fail_if_exists default=true>"
  task :upload_latest_release, [:fail_if_exists] => [:login] do | t, args |
    fail_if_exists = args[:fail_if_exists] || "true"
    puts "Uploading latest release"
    Dir.chdir(bosh_env.release_dir) do
      config = YAML.load_file("config/dev.yml")
      release_yml = config['latest_release_filename']
      puts "  using filename #{release_yml}"
      result = `bosh --non-interactive upload release`
      if result.include?("has already been uploaded")
         if fail_if_exists[0] == "t"
          fail "bosh upload release failed. Result:\n#{result}"
         else
           puts "  warning: this release has already been uploaded."
         end
      else
        unless /Task [\d]+: state is 'done'/.match(result)
          fail "bosh upload release failed. Result:\n#{result}"
        end
      end
    end
  end

  desc "Generate manifest"
  task :generate_manifest do
    puts "Generating manifest"
    config = YAML.load_file("#{bosh_env.release_dir}/config/dev.yml")
    # Parse the release number out of the "latest_release_filename"
    unless File.exists?(bosh_env.manifest_src)
      fail "Could not find #{bosh_env.manifest_src}"
    end
    manifest = YAML.load_file(bosh_env.manifest_src)
    config['latest_release_filename'] =~ /([0-9]*).yml/
    match_data = Regexp.last_match
    # Support for override properties here for upgrade/downgrade testing
    release_name = ENV['RELEASE_NAME_OVERRIDE'] || config['name']
    version_string = ENV['RELEASE_VERSION_OVERRIDE'] || match_data[1]
    manifest['release'] = {'name' => release_name, 'version' => version_string.to_i}
    bosh_env.manifest_file.rewind
    bosh_env.manifest_file << manifest.to_yaml
    bosh_env.manifest_file.flush
  end

  # This is not typically used as it will cause the deployment
  # to be really slow.  But it is here in case we ever want to
  # do it all the time, or maybe if a bvt tests fails we could
  # do a delete and redploy to see if it was due to stale test
  # state or something.
  desc "Delete deployment"
  task :delete_deployment do
    puts "Deleting deployment"
    config = YAML.load_file(bosh_env.manifest_src)
    result = `bosh --non-interactive delete deployment #{config['name']}`
    unless /Task [\d]+: state is 'done'/.match(result)
      fail "bosh delete deployment failed. Result:\n#{result}"
    end
  end

  desc "Deploy AppCloud via BOSH"
  task :deploy => [:login, :generate_manifest, :deployment] do
    puts "Deploying release via BOSH"
    result = `bosh --non-interactive deploy`
    puts "SGH_DEBUG: output from deploy is: \n #{result}"
    unless /Task [\d]+: state is 'done'/.match(result)
      fail "bosh deploy failed. Result:\n#{result}"
    end

  end

  # The dependencies for all actions are on this task rather than
  # putting a dependency of :create_release on :upload_latest,
  # for example, so that the individual tasks can be run in isolation
  # for debugging.
  desc "Update release dir, and deploy via BOSH"
  task :prep_create_and_deploy => [:prep_release_dir, :create_release, :upload_latest_release, :deploy] do; end

  desc "Deploy existing release dir via BOSH"
  task :create_and_deploy => [:create_release, :upload_latest_release, :deploy] do; end

  desc "Create and deploy a release, continue if already deployed"
  task :create_and_deploy_keep_going do
    Rake.application.invoke_task("ci_bosh:create_release[false]")
    Rake.application.invoke_task("ci_bosh:upload_latest_release[false]")
    Rake.application.invoke_task("ci_bosh:deploy")
  end

end
