require 'securerandom'

module Bosh::Director
  module Api
    class CompiledPackageGroupManager
      include ApiHelper

      def create_from_file_path(user, path)
        unless File.exists?(path)
          raise DirectorError, "Failed to import compiled packages: file not found - #{path}"
        end

        JobQueue.new.enqueue(user, Jobs::ImportCompiledPackages, 'import compiled packages', [path])
      end
    end
  end
end
