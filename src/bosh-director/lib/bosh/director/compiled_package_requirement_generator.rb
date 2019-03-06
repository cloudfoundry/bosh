require 'bosh/director'

module Bosh::Director
  class CompiledPackageRequirementGenerator
    def initialize(logger, event_log_stage, compiled_package_finder)
      @logger = logger
      @event_log_stage = event_log_stage
      @compiled_package_finder = compiled_package_finder
    end

    # The rquirements hash passed in by the caller will be populated with CompiledPackageRequirement objects
    def generate!(requirements, instance_group, job, package, stemcell)
      # Our assumption here is that package dependency graph
      # has no cycles: this is being enforced on release upload.
      # Other than that it's a vanilla Depth-First Search (DFS).

      @logger.info("Checking whether package '#{package.desc}' needs to be compiled for stemcell '#{stemcell.desc}'")
      requirement_key = [package.id, "#{stemcell.os}/#{stemcell.version}"]
      requirement = requirements[requirement_key]

      if requirement # We already visited this and its dependencies
        requirement.add_instance_group(instance_group) # But we still need to register with this instance group
        return requirement
      end

      package_dependency_manager = PackageDependenciesManager.new(job.release.model)

      requirement = create_requirement(instance_group, job, package, stemcell, package_dependency_manager)

      @logger.info("Processing package '#{package.desc}' dependencies")
      dependencies = package_dependency_manager.dependencies(package)
      dependencies.each do |dependency|
        @logger.info("Package '#{package.desc}' depends on package '#{dependency.desc}'")
        dependency_requirement = generate!(requirements, instance_group, job, dependency, stemcell)
        requirement.add_dependency(dependency_requirement)
      end

      requirements[requirement_key] = requirement
      requirement
    end

    private

    def create_requirement(instance_group, job, package, stemcell, package_dependency_manager)
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

      CompiledPackageRequirement.new(
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
