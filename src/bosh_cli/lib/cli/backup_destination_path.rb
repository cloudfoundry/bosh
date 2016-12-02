# encoding: UTF-8

module Bosh::Cli
  class BackupDestinationPath
    def initialize(director)
      @director = director
    end

    def create_from_path(dest_path = nil)
      dest_path ||= Dir.pwd

      if File.directory?(dest_path)
        File.join(dest_path, default_backup_name)
      else
        is_tar_path?(dest_path) ? dest_path : "#{dest_path}.tgz"
      end
    end

    private

    def default_backup_name
      "bosh_backup_#{bosh_director_name}_#{Time.now.to_i}.tgz"
    end

    def bosh_director_name
      @director.get_status['name']
    end

    def is_tar_path?(path)
      path.end_with?('.tar.gz') || path.end_with?('.tgz')
    end
  end
end