
module Bosh::Agent
  module Message
    class Apply
      def self.process(args)
        self.new(args).apply
      end
      def self.long_running?; true; end

      def initialize(args)
        @apply_spec = args.first
        @logger = Bosh::Agent::Config.logger
        @base_dir = Bosh::Agent::Config.base_dir

        @packages_data = File.join(@base_dir, 'data', 'packages')

        %w{ packages bosh jobs monit }.each do |dir|
          FileUtils.mkdir_p(File.join(@base_dir, dir))
        end

        @state_file = File.join(@base_dir, '/bosh/state.yml')

        bsc_options = Bosh::Agent::Config.blobstore_options
        @blobstore_client = Bosh::Blobstore::SimpleBlobstoreClient.new(bsc_options)
      end

      def apply
        @logger.info("Applying: #{@apply_spec.inspect}")

        if File.exist?(@state_file)
          @state = YAML.load_file(@state_file)
        else
          @state = {}
          @state["deployment"] = ""
        end

        if @state["deployment"].empty?
          @state["deployment"] = @apply_spec["deployment"]
          @state["resource_pool"] = @apply_spec['resource_pool']
          @state["networks"] = @apply_spec['networks']
        end

        unless @state["deployment"] == @apply_spec["deployment"]
          raise Bosh::Agent::MessageHandlerError, 
            "attempt to apply #{@apply_spec["deployment"]} to #{@state["deployment"]}"
        end

        begin
          apply_packages
          apply_job
        rescue Exception => e
          raise Bosh::Agent::MessageHandlerError, "#{e.message}: #{e.backtrace}"
        end

        # FIXME: assumption right now: if apply succeeds @state should be
        # identical with apply spec
        @state = @apply_spec
        write_state
        @state
      end

      def apply_packages

        if @apply_spec['packages'] == nil
          @logger.info("No packages")
          return
        end

        @apply_spec['packages'].each do |pkg_name, pkg|
          @logger.info("Installing: #{pkg.inspect}")

          blobstore_id = pkg['blobstore_id']
          install_dir = File.join(@packages_data, pkg['name'], pkg['version'])

          Util.unpack_blob(blobstore_id, install_dir)

          pkg_link_dst = File.join(@base_dir, 'packages', pkg['name'])
          FileUtils.ln_sf(install_dir, pkg_link_dst)
        end

      end

      def apply_job

        if @apply_spec['job'] == nil
          @logger.info("No job")
          return
        end

        # temporary hack
        unless @apply_spec['job'].is_a?(Hash)
          return
        end

        job = @apply_spec['job']
        version = @apply_spec['release']['version'].to_s
        blobstore_id = job['blobstore_id']
        name = job['name']

        install_dir = File.join(@base_dir, 'data', 'jobs', name, version)
        Util.unpack_blob(blobstore_id, install_dir)

        job_link_dst = File.join(@base_dir, 'jobs', name)
        FileUtils.ln_sf(install_dir, job_link_dst)

        # TODO ERB/Template
        monit_file = File.join(install_dir, 'monit')
        if File.exist?(monit_file)
          monit_link = File.join(@base_dir, 'monit', "#{name}.monitrc")
          FileUtils.ln_sf(monit_file, monit_link)
        end

      end

      def write_state
        # FIXME: use temporary file and move in place
        File.open(@state_file, 'w') do |f|
          f.puts(@state.to_yaml)
        end
      end

    end
  end
end
