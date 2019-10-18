module Bosh::Director
  class CompiledPackageRequirement
    # @return [Models::Package] What package is being compiled
    attr_reader :package

    # @return [Models::Stemcell] What stemcell package is compiled for
    attr_reader :stemcell

    # @return [Array<DeploymentPlan::InstanceGroup>] InstanceGroups interested in this package
    attr_reader :instance_groups

    # @return [Models::CompiledPackage] Compiled package DB model
    attr_reader :compiled_package

    # @return [String] Dependency key (changing it will trigger recompilation
    #   even when package bits haven't changed)
    attr_accessor :dependency_key

    # @return [Array<CompiledPackageRequirement>] Requirements this depends on
    attr_reader :dependencies

    # @return [Array<CompiledPackageRequirement>] Requirements depending on this
    attr_reader :dependent_requirements

    # @return [String] A unique checksum based on the dependencies in this task
    attr_reader :cache_key

    def initialize(package:, stemcell:, initial_instance_group:, dependency_key:, cache_key:, compiled_package:)
      @package = package
      @stemcell = stemcell

      @instance_groups = []
      add_instance_group(initial_instance_group)
      @dependencies = []
      @dependent_requirements = []

      @dependency_key = dependency_key
      @cache_key = cache_key
      @compiled_package = compiled_package
    end

    # @return [Boolean] Whether this task is ready to be compiled
    def ready_to_compile?
      !compiled? && all_dependencies_compiled?
    end

    # @return [Boolean]
    def all_dependencies_compiled?
      @dependencies.all?(&:compiled?)
    end

    # @return [Boolean]
    def compiled?
      !@compiled_package.nil?
    end

    # Makes compiled package available to all instance_groups waiting for it
    # @param [Models::CompiledPackage] compiled_package Compiled package
    # @return [void]
    def use_compiled_package(compiled_package)
      @compiled_package = compiled_package

      @instance_groups.each do |instance_group|
        instance_group.use_compiled_package(@compiled_package)
      end
    end

    # @note Cycle detection is done elsewhere
    # @param [DeploymentPlan::InstanceGroup] instance_group to be added
    # @return [void]
    def add_instance_group(instance_group)
      return if @instance_groups.include?(instance_group)

      @instance_groups << instance_group
      return unless @compiled_package

      # If package is already compiled we can make it available to instance_group
      # immediately, otherwise it will be done by #use_compiled_package
      instance_group.use_compiled_package(@compiled_package)
    end

    # Adds a package compilation spec to the list of dependencies
    # @note Cycle detection performed elsewhere
    # @param [CompiledPackageRequirement]
    # @param [Boolean] reciprocate If true, add self as dependency to other
    # @return [void]
    def add_dependency(requirement, reciprocate = true)
      @dependencies << requirement
      requirement.add_dependent_requirement(self, false) if reciprocate
    end

    # Adds a compilation requirement to the list of dependencies
    # @note Cycle detection performed elsewhere
    # @param [CompiledPackageRequirement]
    # @param [Boolean] reciprocate If true, add self as dependency to to other
    # @return [void]
    def add_dependent_requirement(requirement, reciprocate = true)
      @dependent_requirements << requirement
      requirement.add_dependency(self, false) if reciprocate
    end

    # This call only makes sense if all dependencies have already been compiled,
    # otherwise it raises an exception
    # @return [Hash] Hash representation of all package dependencies. Agent uses
    #   that to download package dependencies before compiling the package on a
    #   compilation VM.
    def dependency_spec
      spec = {}

      @dependencies.each do |dependency|
        unless dependency.compiled?
          raise DirectorError,
                'Cannot generate package dependency spec ' \
                "for '#{@package.name}', " \
                "'#{dependency.package.name}' hasn't been compiled yet"
        end

        compiled_package = dependency.compiled_package

        spec[compiled_package.name] = {
          'name' => compiled_package.name,
          'version' => "#{compiled_package.version}.#{compiled_package.build}",
          'sha1' => compiled_package.sha1,
          'blobstore_id' => compiled_package.blobstore_id,
        }
      end
      spec
    end
  end
end
