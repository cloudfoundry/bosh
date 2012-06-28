# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent
  module ApplyPlan
    class Job

      class InstallationError < StandardError; end
      class ConfigurationError < StandardError; end

      attr_reader :install_path
      attr_reader :link_path
      attr_reader :template

      # Initializes a job.
      # @param [String] job_name The name of the job being set up, such as
      #     "nats".
      # @param [Hash] template_spec A hash that came from the apply spec
      #     message.  This hash contains information about the template that is
      #     to be setup in this job.  It has keys such as:
      #     "name", "version", "sha1", "blobstore_id"
      # @param [Bosh::Agent::Util::BindingHelper] config_binding A binding
      #     helper instance.
      def initialize(job_name, template_spec, config_binding = nil)
        unless template_spec.is_a?(Hash)
          raise ArgumentError, "Invalid job template_spec, " +
                               "Hash expected, #{template_spec.class} given"
        end

        %w(name version sha1 blobstore_id).each do |key|
          if template_spec[key].nil?
            raise ArgumentError, "Invalid spec, #{key} is missing"
          end
        end

        @base_dir = Bosh::Agent::Config.base_dir
        @name = "#{job_name}.#{template_spec["name"]}"
        @template = template_spec["name"]
        @version = template_spec["version"]
        @checksum = template_spec["sha1"]
        @blobstore_id = template_spec["blobstore_id"]
        @config_binding = config_binding

        @install_path = File.join(@base_dir, "data", "jobs",
                                  @template, @version)
        @link_path = File.join(@base_dir, "jobs", @template)
      end

      def install
        fetch_template
        bind_configuration
        harden_permissions
      rescue SystemCallError => e
        install_failed("system call error: #{e.message}")
      end

      def configure
        run_post_install_hook
        configure_monit
      rescue SystemCallError => e
        config_failed("system call error: #{e.message}")
      end

      private

      def fetch_template
        FileUtils.mkdir_p(File.dirname(@install_path))
        FileUtils.mkdir_p(File.dirname(@link_path))

        Bosh::Agent::Util.unpack_blob(@blobstore_id, @checksum, @install_path)
        Bosh::Agent::Util.create_symlink(@install_path, @link_path)
      end

      def bind_configuration
        if @config_binding.nil?
          install_failed("unable to bind configuration, " +
                         "no binding provided")
        end

        bin_dir = File.join(@install_path, "bin")
        manifest_path = File.join(@install_path, "job.MF")

        unless File.exists?(manifest_path)
          install_failed("cannot find job manifest")
        end

        FileUtils.mkdir_p(bin_dir)

        begin
          manifest = YAML.load_file(manifest_path)
        rescue ArgumentError
          install_failed("malformed job manifest")
        end

        unless manifest.is_a?(Hash)
          install_failed("invalid job manifest, " +
                         "Hash expected, #{manifest.class} given")
        end

        templates = manifest["templates"] || {}

        unless templates.kind_of?(Hash)
          install_failed("invalid value for templates in job manifest, " +
                         "Hash expected, #{templates.class} given")
        end

        templates.each_pair do |src, dst|
          template_path = File.join(@install_path, "templates", src)
          output_path = File.join(@install_path, dst)

          unless File.exists?(template_path)
            install_failed("template '#{src}' doesn't exist")
          end

          template = ERB.new(File.read(template_path))
          begin
            result = template.result(@config_binding)
          rescue Exception => e
            # We are essentially running an arbitrary code,
            # hence such a generic rescue clause
            line = e.backtrace.first.match(/:(\d+):/).captures.first
            install_failed("failed to process configuration template " +
                           "'#{src}': " +
                           "line #{line}, error: #{e.message}")
          end

          FileUtils.mkdir_p(File.dirname(output_path))
          File.open(output_path, "w") { |f| f.write(result) }

          if File.basename(File.dirname(output_path)) == "bin"
            FileUtils.chmod(0755, output_path)
          end
        end
      end

      def harden_permissions
        return unless Bosh::Agent::Config.configure

        FileUtils.chown_R("root", Bosh::Agent::BOSH_APP_USER, @install_path)
        chmod_others = "chmod -R o-rwx #{@install_path} 2>&1"
        chmod_group = "chmod g+rx #{@install_path} 2>&1"

        out = %x(#{chmod_others})
        unless $?.exitstatus == 0
          install_failed("error executing '#{chmod_others}': #{out}")
        end

        out = %x(#{chmod_group})
        unless $?.exitstatus == 0
          install_failed("error executing '#{chmod_group}': #{out}")
        end
      end

      # TODO: move from util here? (not being used anywhere else)
      def run_post_install_hook
        Bosh::Agent::Util.run_hook("post_install", @template)
      end

      def configure_monit
        Dir.foreach(@install_path).each do |file|
          full_path = File.expand_path(file, @install_path)

          if file == "monit"
            install_job_monitrc(full_path, @name)
          elsif file =~ /(.*)\.monit$/
            install_job_monitrc(full_path, "#{@name}_#{$1}")
          end
        end
      end

      def install_job_monitrc(template_path, label)
        if @config_binding.nil?
          config_failed("Unable to configure monit, " +
                        "no binding provided")
        end

        template = ERB.new(File.read(template_path))
        out_file = File.join(@install_path, "#{label}.monitrc")

        begin
          result = template.result(@config_binding)
        rescue Exception => e
          line = e.backtrace.first.match(/:(\d+):/).captures.first
          config_failed("failed to process monit template " +
                        "'#{File.basename(template_path)}': " +
                        "line #{line}, error: #{e.message}")
        end

        File.open(out_file, "w") do |f|
          f.write(add_modes(result))
        end

        # Monit will load all {base_dir}/monit/job/*.monitrc files,
        # so we need to blow away this directory when we clean up.
        link_path = File.join(@base_dir, "monit", "job", "#{label}.monitrc")

        FileUtils.mkdir_p(File.dirname(link_path))
        Bosh::Agent::Util.create_symlink(out_file, link_path)
      end

      # HACK
      # Force manual mode on all services which don't have mode already set.
      # FIXME: this parser is very simple and thus generates space-delimited
      # output. Can be improved to respect indentation for mode. Also it doesn't
      # skip quoted tokens.
      def add_modes(job_monitrc)
        state = :out
        need_mode = true
        result = ""

        tokens = job_monitrc.split(/\s+/)

        return "" if tokens.empty?

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

      def install_failed(message)
        raise InstallationError, "Failed to install job '#{@name}': #{message}"
      end

      def config_failed(message)
        raise ConfigurationError, "Failed to configure job " +
                                  "'#{@name}': #{message}"
      end

    end
  end
end
