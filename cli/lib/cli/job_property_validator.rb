# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli
  class JobPropertyValidator
    # TODO: tests

    attr_reader :template_errors
    attr_reader :jobs_without_properties

    # @param [Array<JobBuilder>] built_jobs Built job templates
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
        bad_manifest("Invalid jobs format in deployment " +
          "manifest, Array expected, #{@manifest["jobs"].class} given")
      end

      @manifest["jobs"].each do |job|
        unless job.is_a?(Hash)
          bad_manifest("Invalid job spec in the manifest " +
                       "Hash expected, #{job.class} given")
        end

        job_name = job["name"]
        if job_name.nil?
          bad_manifest("Manifest contains at least one job without name")
        end

        if job["template"].nil?
          bad_manifest("Job `#{job_name}' doesn't have a template")
        end
      end

      @template_errors = []
      # TODO: track missing props and show the list to user (super helpful!)
    end

    def validate
      @manifest["jobs"].each do |job_spec|
        validate_templates(job_spec)
      end
    end

    # Tries to fill in each job template with job properties, collects errors
    # @param [Hash] job_spec Job spec from the manifest
    def validate_templates(job_spec)
      built_job = @built_jobs[job_spec["template"]]

      if built_job.nil?
        raise CliError, "Job `#{job_spec["template"]}' has not been built"
      end

      collection = JobPropertyCollection.new(
        built_job, @manifest["properties"],
        job_spec["properties"], job_spec["property_mappings"])

      # Spec is usually more than that but jobs rarely use anything but
      # networks and properties.
      # TODO: provide all keys in the spec?
      spec = {
        "job" => {
          "name" => job_spec["name"]
        },
        "networks" => {
          "default" => {"ip" => "10.0.0.1"}
        },
        "properties" => collection.to_hash,
        "index" => 0
      }

      built_job.all_templates.each do |template_path|
        # TODO: add progress bar?
        evaluate_template(built_job, template_path, spec)
      end
    end

    private

    # @param [JobBuilder] job Job builder
    # @param [String] template_path Template path
    # @param [Hash] spec Fake instance spec
    def evaluate_template(job, template_path, spec)
      erb = ERB.new(File.read(template_path))
      context = Bosh::Common::TemplateEvaluationContext.new(spec)
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

      # @param [JobBuilder] job
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