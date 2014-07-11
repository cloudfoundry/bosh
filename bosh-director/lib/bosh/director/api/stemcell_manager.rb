require 'securerandom'

module Bosh::Director
  module Api
    class StemcellManager
      include ApiHelper

      def find_by_name_and_version(name, version)
        stemcell = Models::Stemcell[:name => name, :version => version]
        if stemcell.nil?
          raise StemcellNotFound,
                "Stemcell `#{name}/#{version}' doesn't exist"
        end
        stemcell
      end

      def stemcell_exists?(name, version)
        find_by_name_and_version(name, version)
        true
      rescue StemcellNotFound
        false
      end

      def create_stemcell_from_url(user, stemcell_url)
        JobQueue.new.enqueue(user, Jobs::UpdateStemcell, 'create stemcell', [stemcell_url, { remote: true }])
      end

      def create_stemcell_from_file_path(user, stemcell_path)
        unless File.exists?(stemcell_path)
          raise DirectorError, "Failed to create stemcell: file not found - #{stemcell_path}"
        end

        JobQueue.new.enqueue(user, Jobs::UpdateStemcell, 'create stemcell', [stemcell_path])
      end

      def delete_stemcell(user, stemcell, options={})
        description = "delete stemcell: #{stemcell.name}/#{stemcell.version}"

        JobQueue.new.enqueue(user, Jobs::DeleteStemcell, description, [stemcell.name, stemcell.version, options])
      end
    end
  end
end
