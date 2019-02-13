module Bosh::Director
  class CompileTask
    # @return [Models::Package] What package is being compiled
    attr_reader :package

    # @return [Models::Stemcell] What stemcell package is compiled for
    attr_reader :stemcell

    # @return [Array<DeploymentPlan::Job>] Jobs interested in this package
    attr_reader :jobs

    # @return [Models::CompiledPackage] Compiled package DB model
    attr_reader :compiled_package

    # @return [String] Dependency key (changing it will trigger recompilation
    #   even when package bits haven't changed)
    attr_accessor :dependency_key

    # @return [Array<CompileTask>] Tasks this task depends on
    attr_reader :dependencies

    # @return [Array<CompileTask>] Tasks depending on this task
    attr_reader :dependent_tasks

    # @return [String] A unique checksum based on the dependencies in this task
    attr_reader :cache_key

    def initialize(package, stemcell, initial_job, dependency_key, cache_key)
      @package = package
      @stemcell = stemcell

      @jobs = []
      add_job(initial_job)
      @dependencies = []
      @dependent_tasks = []

      @dependency_key = dependency_key
      @cache_key = cache_key
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

    # Makes compiled package available to all jobs waiting for it
    # @param [Models::CompiledPackage] compiled_package Compiled package
    # @return [void]
    def use_compiled_package(compiled_package)
      @compiled_package = compiled_package

      @jobs.each do |job|
        job.use_compiled_package(@compiled_package)
      end
    end

    # Adds job to a list of job requiring this compiled package
    # @note Cycle detection is done elsewhere
    # @param [DeploymentPlan::Job] job Job to be added
    # @return [void]
    def add_job(job)
      return if @jobs.include?(job)

      @jobs << job
      return unless @compiled_package

      # If package is already compiled we can make it available to job
      # immediately, otherwise it will be done by #use_compiled_package
      job.use_compiled_package(@compiled_package)
    end

    # Adds a compilation task to the list of dependencies
    # @note Cycle detection performed elsewhere
    # @param [CompileTask] task Compilation task
    # @param [Boolean] reciprocate If true, add self as dependent task to other
    # @return [void]
    def add_dependency(task, reciprocate = true)
      @dependencies << task
      task.add_dependent_task(self, false) if reciprocate
    end

    # Adds a compilation task to the list of dependent tasks
    # @note Cycle detection performed elsewhere
    # @param [CompileTask] task Compilation task
    # @param [Boolean] reciprocate If true, add self as dependency to to other
    # @return [void]
    def add_dependent_task(task, reciprocate = true)
      @dependent_tasks << task
      task.add_dependency(self, false) if reciprocate
    end

    # This call only makes sense if all dependencies have already been compiled,
    # otherwise it raises an exception
    # @return [Hash] Hash representation of all package dependencies. Agent uses
    #   that to download package dependencies before compiling the package on a
    #   compilation VM.
    def dependency_spec
      spec = {}

      @dependencies.each do |dep_task|
        unless dep_task.compiled?
          raise DirectorError,
                'Cannot generate package dependency spec ' \
                "for '#{@package.name}', " \
                "'#{dep_task.package.name}' hasn't been compiled yet"
        end

        compiled_package = dep_task.compiled_package

        spec[compiled_package.name] = {
          'name' => compiled_package.name,
          'version' => "#{compiled_package.version}.#{compiled_package.build}",
          'sha1' => compiled_package.sha1,
          'blobstore_id' => compiled_package.blobstore_id,
        }
      end

      spec
    end

    # @param [CompileTask] task
    # @return [Models::CompiledPackage]
    def find_compiled_package(logger, event_log_stage)
      # if `package` has source associated with it (blobstore_id and sha1)
      #   then we need an exact match in find_compiled_package

      package_already_compiled = !@package.blobstore_id.nil?

      compiled_package = package_already_compiled ? compiled_package_for_exact_stemcell : find_best_compiled_package_by_version
      if compiled_package
        logger.info("Found compiled version of package '#{package.desc}' for stemcell '#{stemcell.desc}'")
        return compiled_package
      end

      cached_package = fetch_from_global_cache(logger, event_log_stage)
      return cached_package if cached_package

      logger.info("Package '#{package.desc}' needs to be compiled on '#{stemcell.desc}'")
      nil
    end

    private

    def compiled_package_for_exact_stemcell
      Models::CompiledPackage[
        package_id: package.id,
        stemcell_os: stemcell.os,
        stemcell_version: stemcell.version,
        dependency_key: dependency_key
      ]
    end

    def find_best_compiled_package_by_version
      compiled_packages_for_stemcell_os = Models::CompiledPackage.where(
        package_id: package.id,
        stemcell_os: stemcell.os,
        dependency_key: dependency_key,
      ).all

      compiled_package_exact_match = compiled_packages_for_stemcell_os.find do |compiled_package_model|
        compiled_package_model.stemcell_version == stemcell.version
      end

      return compiled_package_exact_match if compiled_package_exact_match

      compiled_package_fuzzy_matches = compiled_packages_for_stemcell_os.select do |compiled_package_model|
        Bosh::Common::Version::StemcellVersion.match(compiled_package_model.stemcell_version, stemcell.version)
      end

      compiled_package_fuzzy_matches.max_by do |compiled_package_model|
        SemiSemantic::Version.parse(compiled_package_model.stemcell_version).release.components[1] || 0
      end
    end

    def fetch_from_global_cache(logger, event_log_stage)
      return unless Config.use_compiled_package_cache? && BlobUtil.exists_in_global_cache?(package, cache_key)

      event_log_stage.advance_and_track("Downloading '#{package.desc}' from global cache") do
        # has side effect of putting CompiledPackage model in db
        logger.info("Found compiled version of package '#{package.desc}' for stemcell '#{stemcell.desc}' in global cache")
        return BlobUtil.fetch_from_global_cache(package, stemcell, cache_key, dependency_key)
      end
    end
  end
end
