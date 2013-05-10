# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module Jobs
    class UpdateStemcell < BaseJob
      include ValidationHelper

      @queue = :normal

      # @param [String] stemcell_file Stemcell tarball path
      def initialize(stemcell_file)
        @stemcell_file = stemcell_file
        @cloud = Config.cloud
        @stemcell_manager = Api::StemcellManager.new
      end

      def perform
        logger.info("Processing update stemcell")
        event_log.begin_stage("Update stemcell", 5)

        stemcell_dir = Dir.mktmpdir("stemcell")

        track_and_log("Extracting stemcell archive") do
          result = Bosh::Exec.sh("tar -C #{stemcell_dir} -xzf #{@stemcell_file} 2>&1", :on_error => :return)
          if result.failed?
            logger.error("Extracting stemcell archive failed in dir #{stemcell_dir}, " +
                         "tar returned #{result.exit_status}, " +
                         "output: #{result.output}")
            raise StemcellInvalidArchive, "Extracting stemcell archive failed. Check task debug log for details."
          end
        end

        track_and_log("Verifying stemcell manifest") do
          stemcell_manifest_file = File.join(stemcell_dir, "stemcell.MF")
          stemcell_manifest = Psych.load_file(stemcell_manifest_file)

          @name = safe_property(stemcell_manifest, "name", :class => String)
          @version = safe_property(stemcell_manifest, "version", :class => String)
          @cloud_properties = safe_property(stemcell_manifest, "cloud_properties", :class => Hash, :optional => true)
          @sha1 = safe_property(stemcell_manifest, "sha1", :class => String)

          logger.info("Found stemcell image `#{@name}/#{@version}', " +
                      "cloud properties are #{@cloud_properties.inspect}")

          logger.info("Verifying stemcell image")
          @stemcell_image = File.join(stemcell_dir, "image")
          unless File.file?(@stemcell_image)
            raise StemcellImageNotFound, "Stemcell image not found"
          end
        end

        track_and_log("Checking if this stemcell already exists") do
          if @stemcell_manager.stemcell_exists?(@name, @version)
            raise StemcellAlreadyExists,
                  "Stemcell `#{@name}/#{@version}' already exists"
          end
        end

        stemcell = Models::Stemcell.new
        stemcell.name = @name
        stemcell.version = @version
        stemcell.sha1 = @sha1

        track_and_log("Uploading stemcell #{@name}/#{@version} to the cloud") do
          stemcell.cid =
            @cloud.create_stemcell(@stemcell_image, @cloud_properties)
          logger.info("Cloud created stemcell: #{stemcell.cid}")
        end

        track_and_log("Save stemcell #{@name}/#{@version} (#{stemcell.cid})") do
          stemcell.save
        end

        "/stemcells/#{stemcell.name}/#{stemcell.version}"
      ensure
        FileUtils.rm_rf(stemcell_dir) if stemcell_dir
        FileUtils.rm_rf(@stemcell_file) if @stemcell_file
      end
    end
  end
end
