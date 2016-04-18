require 'bosh/director'

module Bosh::Director
  class CompileTaskGenerator
    def initialize(logger, event_log_stage)
      @logger = logger
      @event_log_stage = event_log_stage
    end

    # The compile_tasks hash passed in by the caller will be populated with CompileTasks objects
    def generate!(compile_tasks, job, template, package, stemcell)
      # Our assumption here is that package dependency graph
      # has no cycles: this is being enforced on release upload.
      # Other than that it's a vanilla Depth-First Search (DFS).

      @logger.info("Checking whether package '#{package.desc}' needs to be compiled for stemcell '#{stemcell.model.desc}'")
      task_key = [package.id, stemcell.id]
      task = compile_tasks[task_key]

      if task # We already visited this task and its dependencies
        task.add_job(job) # But we still need to register this job with task
        return task
      end

      release_version = template.release.model
      package_dependency_manager = PackageDependenciesManager.new(release_version)
      transitive_dependencies = package_dependency_manager.transitive_dependencies(package)
      package_dependency_key = KeyGenerator.new.dependency_key_from_models(package, release_version)
      package_cache_key = Models::CompiledPackage.create_cache_key(package, transitive_dependencies, stemcell.model.sha1)

      task = CompileTask.new(package, stemcell, job, package_dependency_key, package_cache_key)

      compiled_package = task.find_compiled_package(@logger, @event_log_stage)
      if compiled_package
        task.use_compiled_package(compiled_package)
      end

      @logger.info("Processing package '#{package.desc}' dependencies")
      dependencies = package_dependency_manager.dependencies(package)
      dependencies.each do |dependency|
        @logger.info("Package '#{package.desc}' depends on package '#{dependency.desc}'")
        dependency_task = generate!(compile_tasks, job, template, dependency, stemcell)
        task.add_dependency(dependency_task)
      end

      compile_tasks[task_key] = task
      task
    end

  end
end
