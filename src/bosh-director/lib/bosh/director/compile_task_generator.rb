require 'bosh/director'

module Bosh::Director
  class CompileTaskGenerator
    def initialize(logger, event_log_stage, compiled_package_finder)
      @logger = logger
      @event_log_stage = event_log_stage
      @compiled_package_finder = compiled_package_finder
    end

    # The compile_tasks hash passed in by the caller will be populated with CompileTasks objects
    def generate!(compile_tasks, instance_group, job, package, stemcell)
      # Our assumption here is that package dependency graph
      # has no cycles: this is being enforced on release upload.
      # Other than that it's a vanilla Depth-First Search (DFS).

      @logger.info("Checking whether package '#{package.desc}' needs to be compiled for stemcell '#{stemcell.desc}'")
      task_key = [package.id, "#{stemcell.os}/#{stemcell.version}"]
      task = compile_tasks[task_key]

      if task # We already visited this task and its dependencies
        task.add_instance_group(instance_group) # But we still need to register this instance group with task
        return task
      end

      package_dependency_manager = PackageDependenciesManager.new(job.release.model)

      task = create_task(instance_group, job, package, stemcell, package_dependency_manager)

      @logger.info("Processing package '#{package.desc}' dependencies")
      dependencies = package_dependency_manager.dependencies(package)
      dependencies.each do |dependency|
        @logger.info("Package '#{package.desc}' depends on package '#{dependency.desc}'")
        dependency_task = generate!(compile_tasks, instance_group, job, dependency, stemcell)
        task.add_dependency(dependency_task)
      end

      compile_tasks[task_key] = task
      task
    end

    private

    def create_task(instance_group, job, package, stemcell, package_dependency_manager)
      transitive_dependencies = package_dependency_manager.transitive_dependencies(package)
      package_dependency_key = KeyGenerator.new.dependency_key_from_models(package, job.release.model)
      package_cache_key = Models::CompiledPackage.create_cache_key(package, transitive_dependencies, stemcell.sha1)

      compiled_package =  @compiled_package_finder.find_compiled_package(
        package: package,
        stemcell: stemcell,
        exported_from: job.release.exported_from,
        dependency_key: package_dependency_key,
        cache_key: package_cache_key,
        event_log_stage: @event_log_stage,
      )

      CompileTask.new(
        package: package,
        stemcell: stemcell,
        initial_instance_group: instance_group,
        dependency_key: package_dependency_key,
        cache_key: package_cache_key,
        compiled_package: compiled_package,
      )
    end
  end
end
