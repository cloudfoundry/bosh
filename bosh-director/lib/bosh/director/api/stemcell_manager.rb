require 'securerandom'
require 'common/version/stemcell_version_list'

module Bosh::Director
  module Api
    class StemcellManager
      include ApiHelper

      def find_by_name_and_version(name, version)
        stemcell = Models::Stemcell[:name => name, :version => version]
        if stemcell.nil?
          raise StemcellNotFound,
                "Stemcell '#{name}/#{version}' doesn't exist"
        end
        stemcell
      end

      def find_all_stemcells
        Models::Stemcell.order_by(Sequel.asc(:name)).map do |stemcell|
          {
            'name' => stemcell.name,
            'operating_system' => stemcell.operating_system,
            'version' => stemcell.version,
            'cid' => stemcell.cid,
            'deployments' => stemcell.deployments.map { |d| { name: d.name } }
          }
        end
      end

      def latest_by_os(os)
        stemcells = Bosh::Director::Models::Stemcell.where(:operating_system => os)

        if stemcells.nil? || stemcells.empty?
          raise StemcellNotFound,
            "Stemcell with Operating System '#{os}' doesn't exist"
        end

        find_latest(stemcells)
      end

      def latest_by_name(name)
        stemcells = Bosh::Director::Models::Stemcell.where(:name => name)

        if stemcells.nil? || stemcells.empty?
          raise StemcellNotFound,
            "Stemcell '#{name}' doesn't exist"
        end

        find_latest(stemcells)
      end

      def find_by_os_and_version(os, version)
        stemcell = Bosh::Director::Models::Stemcell.
            dataset.order(:name)[:operating_system => os, :version => version]
        if stemcell.nil?
          raise StemcellNotFound,
                "Stemcell version '#{version}' for OS '#{os}' doesn't exist"
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

      private

      def find_latest(stemcells)
        versions = stemcells.map(&:version)

        latest_version = Bosh::Common::Version::StemcellVersionList.parse(versions).latest.to_s

        latest_stemcell = stemcells.find do |stemcell|
          parsed_version = Bosh::Common::Version::StemcellVersion.parse(stemcell.version).to_s
          parsed_version == latest_version
        end

        latest_stemcell
      end
    end
  end
end
