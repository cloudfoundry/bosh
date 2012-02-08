module Bosh::Cli
  module Command
    class Base
      BLOBS_DIR = "blobs"
      BLOBS_INDEX_FILE = "blob_index.yml"

      attr_reader   :cache, :config, :options, :work_dir
      attr_accessor :out, :usage

      def initialize(options = {})
        @options     = options.dup
        @work_dir    = Dir.pwd
        @config      = Config.new(@options[:config] || Bosh::Cli::DEFAULT_CONFIG_PATH)
        @cache       = Cache.new(@options[:cache_dir] || Bosh::Cli::DEFAULT_CACHE_DIR)
      end

      def director
        @director ||= Bosh::Cli::Director.new(target, username, password)
      end

      def release
        return @release if @release
        check_if_release_dir
        @release = Bosh::Cli::Release.new(@work_dir)
      end

      def blobstore
        release.blobstore
      end

      def logged_in?
        username && password
      end

      def non_interactive?
        !interactive?
      end

      def interactive?
        !options[:non_interactive]
      end

      def verbose?
        options[:verbose]
      end

      # TODO: implement it
      def dry_run?
        options[:dry_run]
      end

      def show_usage
        say "Usage: #{@usage}" if @usage
      end

      def run(namespace, action, *args)
        eval(namespace.to_s.capitalize).new(options).send(action.to_sym, *args)
      end

      def redirect(*args)
        run(*args)
        raise Bosh::Cli::GracefulExit, "redirected to %s" % [ args.join(" ") ]
      end

      def confirmed?(question = "Are you sure?")
        non_interactive? || ask("#{question} (type 'yes' to continue): ") == "yes"
      end

      [:username, :password, :target, :deployment].each do |attr_name|
        define_method attr_name do
          config.send(attr_name)
        end
      end

      alias_method :target_url, :target

      def target_name
        config.target_name || target_url
      end

      def target_version
        config.target_version ? "Ver: " + config.target_version : ""
      end

      def full_target_name
        ret = (target_name.blank? || target_name == target_url ? target_name : "%s (%s)" % [ target_name, target_url])
        ret + " %s" % target_version if ret
      end

      ##
      # Returns whether there is currently a task running.  A wrapper for the
      # director.rb method.
      #
      # @return [Boolean] Whether there is a task currently running.
      def task_running?
        director.has_current?
      end

      ##
      # Cancels the task currently running.  A wrapper for the director.rb
      # method.
      def cancel_current_task
        director.cancel_current
      end

      protected

      def auth_required
        target_required
        err("Please log in first") unless logged_in?
      end

      def target_required
        err("Please choose target first") if target.nil?
      end

      def deployment_required
        err("Please choose deployment first") if deployment.nil?
      end

      def check_if_release_dir
        if !in_release_dir?
          err "Sorry, your current directory doesn't look like release directory"
        end
      end

      def check_if_dirty_state
        if dirty_state?
          say "\n%s\n" % [ `git status` ]
          err "Your current directory has some local modifications, please discard or commit them first"
        end
      end

      def in_release_dir?
        File.directory?("packages") && File.directory?("jobs") && File.directory?("src")
      end

      def dirty_state?
        `which git`
        return false unless $? == 0
        File.directory?(".git") && `git status --porcelain | wc -l`.to_i > 0
      end

      def normalize_url(url)
        url = "http://#{url}" unless url.match(/^https?/)
        URI.parse(url).to_s
      end

      def check_if_blobs_supported
        check_if_release_dir
        if !File.directory?(BLOBS_DIR)
          err "Can't find blob directory '#{BLOBS_DIR}'."
        end

        if !File.file?(BLOBS_INDEX_FILE)
          err "Can't find '#{BLOBS_INDEX_FILE}'"
        end
      end

      def check_dirty_blobs
        if File.file?(File.join(work_dir, BLOBS_INDEX_FILE)) && blob_status != 0
          err "Your 'blobs' directory is not in sync. Resolve using 'bosh blobs' commands"
        end
      end

      def get_blobs_index
        load_yaml_file(File.join(work_dir, BLOBS_INDEX_FILE))
      end

      def blob_status(verbose = false)
        check_if_blobs_supported
        untracked = []
        modified = []
        tracked= []
        unsynced = []

        local_blobs = {}
        Dir.chdir(BLOBS_DIR) do
          Dir.glob("**/*").select { |entry| File.file?(entry) }.each do |file|
            local_blobs[file] = Digest::SHA1.file(file).hexdigest
          end
        end
        remote_blobs = get_blobs_index

        local_blobs.each do |blob_name, blob_sha|
          if remote_blobs[blob_name].nil?
            untracked << blob_name
          elsif blob_sha != remote_blobs[blob_name]["sha"]
            modified << blob_name
          else
            tracked << blob_name
          end
        end

        remote_blobs.each_key do |blob_name|
          unsynced << blob_name if local_blobs[blob_name].nil?
        end

        changes = modified.size + untracked.size + unsynced.size
        return changes unless verbose

        if modified.size > 0
          say "\nModified blobs ('bosh upload blob' to update): ".green
          modified.each { |blob| say blob }
        end

        if untracked.size > 0
          say "\nNew blobs ('bosh upload blob' to add): ".green
          untracked.each { |blob| say blob }
        end

        if unsynced.size > 0
          say "\nMissing blobs ('bosh sync blobs' to fetch) : ".green
          unsynced.each { |blob| say blob }
        end

        if changes == 0
          say "\nRelease blobs are up to date".green
        end
        changes
      end
    end
  end
end
