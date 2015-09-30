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

      def find_by_os_and_version(os, version)
        stemcell = Bosh::Director::Models::Stemcell.
            dataset.order(:name)[:operating_system => os, :version => version]
        if stemcell.nil?
          raise StemcellNotFound,
                "Stemcell version `#{version}' for OS `#{os}' doesn't exist"
        end
        stemcell
      end

      def stemcell_exists?(name, version)
        find_by_name_and_version(name, version)
        true
      rescue StemcellNotFound
        false
      end

      def create_stemcell_from_url(username, stemcell_url, options)
        options[:remote] = true
        JobQueue.new.enqueue(username, Jobs::UpdateStemcell, 'create stemcell', [stemcell_url, options])
      end

      def create_stemcell_from_file_path(username, stemcell_path, options)
        unless File.exists?(stemcell_path)
          raise DirectorError, "Failed to create stemcell: file not found - #{stemcell_path}"
        end

        JobQueue.new.enqueue(username, Jobs::UpdateStemcell, 'create stemcell', [stemcell_path, options])
      end

      def delete_stemcell(username, stemcell, options={})
        description = "delete stemcell: #{stemcell.name}/#{stemcell.version}"

        JobQueue.new.enqueue(username, Jobs::DeleteStemcell, description, [stemcell.name, stemcell.version, options])
      end
    end
  end
end
