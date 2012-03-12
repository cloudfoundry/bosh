# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  class CompileTask
    attr_accessor :key
    attr_accessor :jobs
    attr_accessor :package
    attr_accessor :stemcell
    attr_accessor :compiled_package
    attr_accessor :dependency_key
    attr_accessor :dependencies

    def initialize(key)
      @key = key
      @jobs = []
      @dependencies = []
    end

    def dependencies_satisfied?
      @dependencies.all? { |dependent_task| dependent_task.compiled_package }
    end

    def ready_to_compile?
      @compiled_package.nil? && dependencies_satisfied?
    end

    def compiled_package= (compiled_package)
      @compiled_package = compiled_package
      if @compiled_package
        @jobs.each { |job| job.add_package(@package, @compiled_package) }
      end
    end

    def add_job(job)
      @jobs << job
      job.add_package(@package, @compiled_package) if @compiled_package
    end

    def dependency_spec
      spec = {}
      @dependencies.each do |dependency|
        package = dependency.package
        compiled_package = dependency.compiled_package
        spec[package.name] = {
            "name" => package.name,
            "version" => "#{package.version}.#{compiled_package.build}",
            "sha1" => compiled_package.sha1,
            "blobstore_id" => compiled_package.blobstore_id
        }
      end
      spec
    end

    def to_s
      "#{package.name}/#{stemcell.name}"
    end
  end
end