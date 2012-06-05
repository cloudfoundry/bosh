# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module Jobs
    class UpdateStemcell < BaseJob
      include ValidationHelper

      @queue = :normal

      # @param [String] stemcell_file Stemcell tarball path
      def initialize(stemcell_file)
        super

        @stemcell_file = stemcell_file
        @cloud = Config.cloud
        @stemcell_manager = Api::StemcellManager.new
      end

      def perform
        logger.info("Processing update stemcell")
        event_log.begin_stage("Update stemcell", 5)

        stemcell_dir = Dir.mktmpdir("stemcell")

        track_and_log("Extracting stemcell archive") do
          output = `tar -C #{stemcell_dir} -xzf #{@stemcell_file} 2>&1`
          if $?.exitstatus != 0
            raise StemcellInvalidArchive,
                  "Invalid stemcell archive, tar returned #{$?.exitstatus}, " +
                  "output: #{output}"
          end
        end

        track_and_log("Verifying stemcell manifest") do
          stemcell_manifest_file = File.join(stemcell_dir, "stemcell.MF")
          stemcell_manifest = YAML.load_file(stemcell_manifest_file)

          @name = safe_property(stemcell_manifest, "name", :class => String)
          @version =
            safe_property(stemcell_manifest, "version", :class => String)
          @cloud_properties =
            safe_property(stemcell_manifest, "cloud_properties",
                          :class => Hash, :optional => true)

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
