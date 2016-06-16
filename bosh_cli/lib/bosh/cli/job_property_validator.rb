# Copyright (c) 2009-2012 VMware, Inc.
require 'bosh/template/evaluation_context'

module Bosh::Cli
  class JobPropertyValidator

    attr_reader :template_errors
    attr_reader :jobs_without_properties

    # @param [Array<Bosh::Cli::Resources::Job>] built_jobs Built job templates
    # @param [Hash] manifest Deployment manifest
    def initialize(built_jobs, manifest)
      @built_jobs = {}
      @manifest = manifest

      @jobs_without_properties = []

      built_jobs.each do |job|
        @built_jobs[job.name] = job
        if job.properties.empty?
          @jobs_without_properties << job
        end
      end

      unless @manifest["properties"].is_a?(Hash)
        bad_manifest("Invalid properties format in deployment " +
          "manifest, Hash expected, #{@manifest["properties"].class} given")
      end

      unless @manifest["jobs"].is_a?(Array)
        bad_manifest("Invalid instance groups format in deployment " +
          "manifest, Array expected, #{@manifest["jobs"].class} given")
      end

      @manifest["jobs"].each do |job|
        unless job.is_a?(Hash)
          bad_manifest("Invalid instance group spec in the manifest " +
                       "Hash expected, #{job.class} given")
        end

        job_name = job["name"]
        if job_name.nil?
          bad_manifest("Manifest contains at least one instance group without name")
        end

        if job["template"].nil?
          bad_manifest("Instance group '#{job_name}' doesn't have a job")
        end
      end

      @template_errors = []
    end

    def validate
      @manifest["jobs"].each do |job_spec|
        job_templates = Array(job_spec['template'])
        job_templates.each do |job_template|
          job_spec_for_template = job_spec.dup
          job_spec_for_template['template'] = job_template
          validate_templates(job_spec_for_template)
        end
      end
    end

    # Tries to fill in each job template with job properties, collects errors
    # @param [Hash] job_spec Job spec from the manifest
    def validate_templates(job_spec)
      built_job = @built_jobs[job_spec["template"]]

      if built_job.nil?
        raise CliError, "Instance group '#{job_spec["template"]}' has not been built"
      end

      collection = JobPropertyCollection.new(
        built_job, @manifest["properties"],
        job_spec["properties"], job_spec["property_mappings"])

      # Spec is usually more than that but jobs rarely use anything but
      # networks and properties.
      spec = {
        'job' => {
            'name' => job_spec['name']
        },
        'index' => 0,
        'networks' => job_network_spec(job_spec),
        'properties' => collection.to_hash
      }

      built_job.files.each do |file_tuple|
        evaluate_template(built_job, file_tuple.first, spec)
      end
    end

    def job_network_spec(job_spec)
      job_spec['networks'].reduce({}) do |networks, network|
        networks[network['name']] = {
            'ip' => '127.0.0.1', # faking the IP since it shouldn't affect logic
            'netmask' => '255.255.255.0',
            'gateway' => '127.0.0.2'
        }
        networks
      end
    end

    private

    # @param [Bosh::Cli::Resources::Job] job Job builder
    # @param [String] template_path Template path
    # @param [Hash] spec Fake instance spec
    def evaluate_template(job, template_path, spec)
      erb = ERB.new(File.read(template_path))
      context = Bosh::Template::EvaluationContext.new(spec)
      begin
        erb.result(context.get_binding)
      rescue Exception => e
        @template_errors << TemplateError.new(job, template_path, e)
      end
    end

    def bad_manifest(message)
      raise InvalidManifest, message
    end

    class TemplateError
      attr_reader :job
      attr_reader :template_path
      attr_reader :exception
      attr_reader :line

      # @param [Bosh::Cli::Resources::Job] job
      # @param [String] template_path
      # @param [Exception] exception
      def initialize(job, template_path, exception)
        @job = job
        @template_path = template_path
        @exception = exception
        @line = exception.backtrace.first.split(":")[1]
      end
    end
  end
end
