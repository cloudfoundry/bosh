module Bosh::Agent
  module Message
    class Apply < Base

      def self.long_running?; true; end

      def self.process(args)
        self.new(args).apply
      end

      def initialize(args)
        @monit_api_client = Bosh::Agent::Monit.monit_api_client
        @apply_spec = args.first
        @job = @apply_spec['job']

        if @job
          @job_template = @job['template']
          @job_version = @job['version']
          @job_install_dir = File.join(base_dir, 'data', 'jobs', @job_template, @job_version)
        end

        @packages_data = File.join(base_dir, 'data', 'packages')

        %w{ packages bosh jobs monit }.each do |dir|
          FileUtils.mkdir_p(File.join(base_dir, dir))
        end

        @platform = Bosh::Agent::Config.platform
      end

      def apply
        logger.info("Applying: #{@apply_spec.inspect}")
        state = Bosh::Agent::Config.state.to_hash

        if !state["deployment"].empty? && (state["deployment"] != @apply_spec["deployment"])
          raise Bosh::Agent::MessageHandlerError, "attempt to apply #{@apply_spec["deployment"]} to #{state["deployment"]}"
        end

        # FIXME: tests
        # return @state if @state['configuraton_hash'] == @apply_spec['configuration_hash']

        if @apply_spec.key?('configuration_hash')
          begin
            apply_job
            apply_packages
            post_install_hook
            configure_monit
            @platform.update_logging(@apply_spec)
          rescue Exception => e
            raise Bosh::Agent::MessageHandlerError, "#{e.message}: #{e.backtrace}"
          end
        end

        # FIXME: assumption right now: if apply succeeds state should be
        # identical with apply spec
        Bosh::Agent::Config.state.write(@apply_spec)
        @apply_spec

      rescue Bosh::Agent::StateError => e
        raise Bosh::Agent::MessageHandlerError, e
      end

      def apply_job
        unless @job
          logger.info("No job")
          return
        end

        blobstore_id = @job['blobstore_id']
        sha1 = @job['sha1']
        Util.unpack_blob(blobstore_id, sha1, @job_install_dir)

        job_link_dst = File.join(base_dir, 'jobs', @job_template)
        link_installed(@job_install_dir, job_link_dst, "Failed to link job: #{@job_install_dir} #{job_link_dst}")

        template_configurations

        if Bosh::Agent::Config.configure
          harden_job_permissions
        end

        FileUtils.mkdir_p(File.join(@job_install_dir, 'packages'))
      end

      def apply_packages

        if @apply_spec['packages'] == nil
          logger.info("No packages")
          return
        end

        @apply_spec['packages'].each do |pkg_name, pkg|
          logger.info("Installing: #{pkg.inspect}")

          blobstore_id = pkg['blobstore_id']
          sha1 = pkg['sha1']
          install_dir = File.join(@packages_data, pkg['name'], pkg['version'])

          Util.unpack_blob(blobstore_id, sha1, install_dir)

          pkg_link_dst = File.join(base_dir, 'packages', pkg['name'])
          job_pkg_link_dst = File.join(@job_install_dir, 'packages', pkg['name'])

          [ pkg_link_dst, job_pkg_link_dst ].each do |dst|
            link_installed(install_dir, dst, "Failed to link package: #{install_dir} #{dst}")
          end
        end

      end

      def link_installed(src, dst, error_msg="Failed to link #{src} to #{dst}")
        # FileUtils doesn have 'no-deference' for links - causing ln_sf to
        # attempt to create target link in dst rather than to overwrite it.
        # BROKEN: FileUtils.ln_sf(monit_file, monit_link)
        `ln -nsf #{src} #{dst}`
        unless $?.exitstatus == 0
          raise Bosh::Agent::MessageHandlerError, error_msg
        end
      end

      def template_configurations
        bin_dir = File.join(@job_install_dir, 'bin')
        FileUtils.mkdir_p(bin_dir)

        file = nil
        job_mf = YAML.load_file(File.join(@job_install_dir, 'job.MF'))
        job_mf['templates'].each do |src, dst|
          file = src
          template = ERB.new(File.read(File.join(@job_install_dir, 'templates', src)))

          out_file = File.join(@job_install_dir, dst)
          FileUtils.mkdir_p(File.dirname(out_file))

          File.open(out_file, 'w') do |fh|
            fh.write(template.result(Util.config_binding(@apply_spec)))
          end

          if File.basename(File.dirname(out_file)) == "bin"
            FileUtils.chmod(0755, out_file)
          end
        end
      rescue NoMethodError => e
        line = e.backtrace.first.match(/:(\d+):/).captures.first
        raise FatalError, "job '#{@job["name"]}' failed to process template #{file}: #{e.message} on line #{line}"
      end

      def harden_job_permissions
        FileUtils.chown_R('root', BOSH_APP_USER, @job_install_dir)
        %x[chmod -R o-rwx #{@job_install_dir}]
        %x[chmod g+rx #{@job_install_dir}]
      end

      def post_install_hook
        Util.run_hook('post_install', @job_template)
      end

      def configure_monit
        # TODO ERB/Template
        monit_template = File.join(@job_install_dir, 'monit')
        if File.exist?(monit_template)
          template = ERB.new(File.read(monit_template))
          monitrc_name = "#{@job_template}.monitrc"

          out_file = File.join(@job_install_dir, monitrc_name)

          original_monitrc = template.result(Util.config_binding(@apply_spec))
          result_monitrc   = add_modes(original_monitrc)

          File.open(out_file, 'w') do |fh|
            fh.write(result_monitrc)
          end

          monit_link = File.join(base_dir, 'monit', "#{@job_template}.monitrc")

          link_installed(out_file, monit_link, "Failed to link monit file: #{out_file} #{monit_link}" )

          if Bosh::Agent::Config.configure
            Bosh::Agent::Monit.reload
          end
        end
      end

      # HACK
      # Force manual mode on all services which don't have mode already set.
      # FIXME: this parser is very simple and thus generates space-delimited
      # output. Can be improved to respect indentation for mode. Also it doesn't
      # skip quoted tokens.
      def add_modes(job_monitrc)
        state     = :out
        need_mode = true
        result    = ""

        tokens = job_monitrc.split(/\s+/)

        while (t = tokens.shift)
          if t == "check"
            if state == :in && need_mode
              result << "mode manual "
            end
            state = :in
            need_mode = true

          elsif t == "mode" && %w(passive manual active).include?(tokens[0])
            need_mode = false
          end

          result << t << " "
        end

        if need_mode
          result << "mode manual "
        end

        result.strip
      end
    end

  end
end
