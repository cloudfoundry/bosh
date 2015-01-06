require 'securerandom'

module Bosh::Director
  module Api
    class CompiledPackageGroupManager
      include ApiHelper

      def create_from_file_path(username, path)
        unless File.exists?(path)
          raise DirectorError, "Failed to import compiled packages: file not found - #{path}"
        end

        JobQueue.new.enqueue(username, Jobs::ImportCompiledPackages, 'import compiled packages', [path])
      end
    end
  end
end
