module Bosh::Director::Jobs
  module Helpers
    class ReleaseDeleter

      def initialize(package_deleter, template_deleter, event_log, logger)
        @package_deleter = package_deleter
        @template_deleter = template_deleter
        @event_log = event_log
        @logger = logger
      end

      def delete(release, force)
        errors = []

        stage = @event_log.begin_stage('Deleting packages', release.packages.count)
        release.packages.each do |package|
          track_and_log(stage, "#{package.name}/#{package.version}") do
            errors += @package_deleter.delete(package, force)
          end
        end

        stage = @event_log.begin_stage('Deleting jobs', release.templates.count)
        release.templates.each do |template|
          track_and_log(stage, "#{template.name}/#{template.version}") do
            errors += @template_deleter.delete(template, force)
          end
        end

        if errors.empty? || force
          stage = @event_log.begin_stage('Deleting release versions', release.versions.count)
          release.versions.each do |release_version|
            track_and_log(stage, "#{release.name}/#{release_version.version}") do
              release_version.destroy
            end
          end
          release.destroy
        end

        errors
      end

      private

      def track_and_log(stage, task, log = true)
        stage.advance_and_track(task) do |ticker|
          @logger.info(task) if log
          yield ticker if block_given?
        end
      end
    end
  end
end
