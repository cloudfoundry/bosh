module Bosh::Cli::Versions
  class MultiReleaseSupport

    def initialize(work_dir, default_release_name, ui)
      @work_dir = work_dir
      @default_release_name = default_release_name
      @ui = ui
    end

    def migrate
      dev_releases_path = File.join(@work_dir, 'dev_releases')
      migrator = ReleasesDirMigrator.new(dev_releases_path, @default_release_name, @ui, 'DEV')
      dev_release_migrated = migrator.migrate

      final_releases_path = File.join(@work_dir, 'releases')
      migrator = ReleasesDirMigrator.new(final_releases_path, @default_release_name, @ui, 'FINAL')
      final_releases_migrated = migrator.migrate

      if final_releases_migrated || dev_release_migrated
        Bosh::Cli::SourceControl::GitIgnore.new(@work_dir).update
      end
    end
  end
end
