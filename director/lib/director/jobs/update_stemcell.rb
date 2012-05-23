# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module Jobs
    class UpdateStemcell < BaseJob
      include ValidationHelper

      @queue = :normal

      def initialize(stemcell_file)
        super
        @stemcell_file = stemcell_file
        @cloud = Config.cloud
      end

      def perform
        @logger.info("Processing update stemcell")
        @event_log.begin_stage("Update stemcell", 5)

        stemcell_dir = Dir.mktmpdir("stemcell")

        track_and_log("Extracting stemcell archive") do
          output = `tar -C #{stemcell_dir} -xzf #{@stemcell_file} 2>&1`
          raise StemcellInvalidArchive.new($?.exitstatus, output) if $?.exitstatus != 0
        end

        track_and_log("Verifying stemcell manifest") do
          stemcell_manifest_file = File.join(stemcell_dir, "stemcell.MF")
          stemcell_manifest = YAML.load_file(stemcell_manifest_file)

          @name = safe_property(stemcell_manifest, "name", :class => String)
          @version = safe_property(stemcell_manifest, "version", :class => String)
          @cloud_properties = safe_property(stemcell_manifest, "cloud_properties", :class => Hash, :optional => true)
          @stemcell_image = File.join(stemcell_dir, "image")
          @logger.info("Found: name=>#{@name}, version=>#{@version}, cloud_properties=>#{@cloud_properties}")

          @logger.info("Verifying stemcell image")
          raise StemcellInvalidImage unless File.file?(@stemcell_image)
        end

        track_and_log("Checking if this stemcell already exists") do
          stemcell = Models::Stemcell[:name => @name, :version => @version]
          raise StemcellAlreadyExists.new(@name, @version) if stemcell
        end

        stemcell = Models::Stemcell.new
        stemcell.name = @name
        stemcell.version = @version

        track_and_log("Uploading stemcell #{@name}/#{@version} to the cloud") do
          stemcell.cid = @cloud.create_stemcell(@stemcell_image, @cloud_properties)
          @logger.info("Cloud created stemcell: #{stemcell.cid}")
        end

        track_and_log("Save stemcell: #{stemcell.name}/#{stemcell.version} (#{stemcell.cid})") do
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
