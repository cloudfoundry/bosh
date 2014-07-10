require 'securerandom'

module Bosh::Director
  module Api
    class CompiledPackageGroupManager
      include ApiHelper

      def create_from_stream(user, stream)
        dir = Dir.tmpdir
        path = File.join(dir, "compiled-package-group-#{SecureRandom.uuid}")

        unless check_available_disk_space(dir, stream.size)
          raise NotEnoughDiskSpace, "Import compiled packages failed. " +
            "Insufficient space on BOSH director in #{dir}"
        end

        write_file(path, stream)

        create_from_file_path(user, path)
      end

      def create_from_file_path(user, path)
        unless File.exists?(path)
          raise DirectorError, "Failed to import compiled packages: file not found - #{path}"
        end

        JobQueue.new.enqueue(user, Jobs::ImportCompiledPackages, 'import compiled packages', [path])
      end
    end
  end
end
