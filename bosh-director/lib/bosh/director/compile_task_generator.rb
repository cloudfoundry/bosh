require 'bosh/director'

module Bosh::Director
  class CompileTaskGenerator
    def initialize(logger, event_log)
      @logger = logger
      @event_log = event_log
    end

    # The compile_tasks hash passed in by the caller will be populated with CompileTasks objects
    def generate!(compile_tasks, job, template, package, stemcell)
      # Our assumption here is that package dependency graph
      # has no cycles: this is being enforced on release upload.
      # Other than that it's a vanilla DFS.

      @logger.info("Checking whether package `#{package.desc}' needs to be compiled for stemcell `#{stemcell.desc}'")
      task_key = [package.id, stemcell.id]
      task = compile_tasks[task_key]

      if task # We already visited this task and its dependencies
        task.add_job(job) # But we still need to register this job with task
        return task
      end

      release_version = template.release.model

      transitive_dependencies = release_version.transitive_dependencies(package)
      package_dependency_key = Models::CompiledPackage.create_dependency_key(transitive_dependencies)
      package_cache_key = Models::CompiledPackage.create_cache_key(package, transitive_dependencies, stemcell)

      task = CompileTask.new(package, stemcell, job, package_dependency_key, package_cache_key)

      compiled_package = task.find_compiled_package(@logger, @event_log)
      if compiled_package
        task.use_compiled_package(compiled_package)
      end

      @logger.info("Processing package `#{package.desc}' dependencies")
      dependencies = release_version.dependencies(package)
      dependencies.each do |dependency|
        @logger.info("Package `#{package.desc}' depends on package `#{dependency.desc}'")
        dependency_task = generate!(compile_tasks, job, template, dependency, stemcell)
        task.add_dependency(dependency_task)
      end

      compile_tasks[task_key] = task
      task
    end

  end
end
