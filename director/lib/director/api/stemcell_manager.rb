# Copyright (c) 2009-2012 VMware, Inc.

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

      def create_stemcell(user, stemcell, options = {})
        if options[:remote]
          stemcell_file = stemcell
        else
          random_name = "stemcell-#{SecureRandom.uuid}"
          stemcell_dir = Dir::tmpdir
          stemcell_file = File.join(stemcell_dir, random_name)

          unless check_available_disk_space(stemcell_dir, stemcell.size)
            raise NotEnoughDiskSpace, "Uploading stemcell archive failed. " +
              "Insufficient space on BOSH director in #{stemcell_dir}"
          end
          
          write_file(stemcell_file, stemcell)
        end

        JobQueue.new.enqueue(user, Jobs::UpdateStemcell, 'create stemcell', [stemcell_file, options])
      end

      def delete_stemcell(user, stemcell, options={})
        description = "delete stemcell: #{stemcell.name}/#{stemcell.version}"

        JobQueue.new.enqueue(user, Jobs::DeleteStemcell, description, [stemcell.name, stemcell.version, options])
      end
    end
  end
end