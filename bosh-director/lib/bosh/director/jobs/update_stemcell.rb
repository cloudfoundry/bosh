require 'securerandom'

module Bosh::Director
  module Jobs
    class UpdateStemcell < BaseJob
      include ValidationHelper
      include DownloadHelper

      UPDATE_STEPS = 5

      @queue = :normal

      def self.job_type
        :update_stemcell
      end

      # @param [String] stemcell_path local path or remote url of the stemcell archive
      # @param [Hash] options Stemcell update options
      def initialize(stemcell_path, options = {})
        if options['remote']
          # file will be downloaded to the stemcell_path
          @stemcell_path = File.join(Dir.tmpdir, "stemcell-#{SecureRandom.uuid}")
          @stemcell_url = stemcell_path
        else
          # file already exists at the stemcell_path
          @stemcell_path = stemcell_path
        end

        @cloud = Config.cloud
        @stemcell_manager = Api::StemcellManager.new
        @fix = options['fix']
      end

      def perform
        logger.info("Processing update stemcell")

        event_log.begin_stage("Update stemcell", @stemcell_url ? UPDATE_STEPS + 1 : UPDATE_STEPS)

        track_and_log("Downloading remote stemcell") { download_remote_stemcell } if @stemcell_url

        stemcell_dir = Dir.mktmpdir("stemcell")

        track_and_log("Extracting stemcell archive") do
          result = Bosh::Exec.sh("tar -C #{stemcell_dir} -xzf #{@stemcell_path} 2>&1", :on_error => :return)
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
          @operating_system = safe_property(stemcell_manifest, "operating_system", :class => String, :optional => true)
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

        stemcell = nil
        track_and_log("Checking if this stemcell already exists") do
          begin
            stemcell = @stemcell_manager.find_by_name_and_version @name, @version
            raise StemcellAlreadyExists, "Stemcell `#{@name}/#{@version}' already exists" unless @fix
          rescue StemcellNotFound => e
            stemcell = Models::Stemcell.new
            stemcell.name = @name
            stemcell.operating_system = @operating_system
            stemcell.version = @version
            stemcell.sha1 = @sha1
          end
        end

        track_and_log("Uploading stemcell #{@name}/#{@version} to the cloud") do
          stemcell.cid = @cloud.create_stemcell(@stemcell_image, @cloud_properties)
          logger.info("Cloud created stemcell: #{stemcell.cid}")
        end

        track_and_log("Save stemcell #{@name}/#{@version} (#{stemcell.cid})") do
          stemcell.save
        end

        "/stemcells/#{stemcell.name}/#{stemcell.version}"
      ensure
        FileUtils.rm_rf(stemcell_dir) if stemcell_dir
        FileUtils.rm_rf(@stemcell_path) if @stemcell_path
      end

      private

      def download_remote_stemcell
        download_remote_file('stemcell', @stemcell_url, @stemcell_path)
      end
    end
  end
end
