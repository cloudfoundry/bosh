module Bosh::Director::Jobs
  module Helpers
    class ReleaseVersionDeleter

      def initialize(release_deleter, package_deleter, template_deleter, logger, event_log)
        @release_deleter = release_deleter
        @package_deleter = package_deleter
        @template_deleter = template_deleter
        @logger = logger
        @event_log = event_log
      end

      def delete(release_version, release, force)
        @logger.info('Checking for any deployments still using ' +
            'this particular release version')

        deployments = release_version.deployments

        unless deployments.empty?
          names = deployments.map { |d| d.name }.join(', ')
          raise Bosh::Director::ReleaseVersionInUse,
            "ReleaseVersion '#{release.name}/#{release_version.version}' is still in use by: #{names}"
        end

        delete_release_version(release_version, force)
      end

      private

      def delete_release_version(release_version, force)
        release = release_version.release

        packages_to_keep = []
        packages_to_delete = []
        templates_to_keep = []
        templates_to_delete = []

        # We don't delete packages inside this loop b/c Sequel will also delete
        # them from packages collection we're iterating on which will lead to
        # skipping some packages
        release_version.packages.each do |package|
          if package.release_versions == [release_version]
            packages_to_delete << package
          else
            packages_to_keep << package
          end
        end

        release_version.templates.each do |template|
          if template.release_versions == [release_version]
            templates_to_delete << template
          else
            templates_to_keep << template
          end
        end

        stage = @event_log.begin_stage('Deleting packages', packages_to_delete.count)
        packages_to_delete.each do |package|
          track_and_log(stage, "#{package.name}/#{package.version}") do
            @logger.info("Package #{package.name}/#{package.version} " +
                'is only used by this release version ' +
                'and will be deleted')
            @package_deleter.delete(package, force)
          end
        end

        packages_to_keep.each do |package|
          @logger.info("Keeping package #{package.name}/#{package.version} " +
              'as it is used by other release versions')
          package.remove_release_version(release_version)
        end

        stage = @event_log.begin_stage('Deleting jobs', templates_to_delete.count)
        templates_to_delete.each do |template|
          track_and_log(stage, "#{template.name}/#{template.version}") do
            @logger.info("Template #{template.name}/#{template.version} " +
                'is only used by this release version ' +
                'and will be deleted')
            @template_deleter.delete(template, force)
          end
        end

        templates_to_keep.each do |template|
          @logger.info('Keeping job ' +
              "#{template.name}/#{template.version} as it is used " +
              'by other release versions')
          template.remove_release_version(release_version)
        end

        @logger.info('Remove all deployments in release version')
        release_version.remove_all_deployments

        release_version.destroy

        if release.versions.empty?
          @release_deleter.delete(release, force)
        end
      end

      def track_and_log(stage, task)
        stage.advance_and_track(task) do
          @logger.info(task)
          yield
        end
      end
    end
  end
end
