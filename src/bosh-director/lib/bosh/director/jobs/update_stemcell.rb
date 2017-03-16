require 'securerandom'

module Bosh::Director
  module Jobs
    class UpdateStemcell < BaseJob
      include ValidationHelper
      include DownloadHelper
      include CloudFactoryHelper

      @queue = :normal
      @local_fs = true

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

        if options['sha1']
          @stemcell_sha1 = options['sha1']
        end

        @multi_digest_verifier = Digest::MultiDigest.new(logger)
        @cloud = Config.cloud
        @stemcell_manager = Api::StemcellManager.new
        @fix = options['fix']
      end

      def perform
        logger.info("Processing update stemcell")

        # adjust numbers in update_steps if you change how many times `track_and_log` are invoked below.
        begin_stage("Update stemcell", update_steps)

        track_and_log("Downloading remote stemcell") { download_remote_stemcell } if @stemcell_url

        stemcell_dir = Dir.mktmpdir("stemcell")

        track_and_log("Verifying remote stemcell") { verify_sha1 } if @stemcell_sha1

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
          stemcell_manifest = YAML.load_file(stemcell_manifest_file)

          @name = safe_property(stemcell_manifest, "name", :class => String)
          @operating_system = safe_property(stemcell_manifest, "operating_system", :class => String, :optional => true, :default => @name)
          @version = safe_property(stemcell_manifest, "version", :class => String)
          @stemcell_formats = safe_property(stemcell_manifest, "stemcell_formats", :class => Array, :optional => true)
          @cloud_properties = safe_property(stemcell_manifest, "cloud_properties", :class => Hash, :optional => true)
          @sha1 = safe_property(stemcell_manifest, "sha1", :class => String)

          logger.info("Found stemcell image '#{@name}/#{@version}', " +
                      "cloud properties are #{@cloud_properties.inspect}")

          logger.info("Verifying stemcell image")
          @stemcell_image = File.join(stemcell_dir, "image")
          unless File.file?(@stemcell_image)
            raise StemcellImageNotFound, "Stemcell image not found"
          end
        end

        stemcell = nil
        cloud_factory.all_configured_clouds.each do |cloud|
          cpi_suffix = " (cpi: #{cloud[:name]})" unless cloud[:name].blank?
          if !is_supported?(cloud)
            logger.info("#{cpi_suffix} cpi does not support stemcell format")
            next
          end
          track_and_log("Checking if this stemcell already exists#{cpi_suffix}") do
            begin
              stemcell = @stemcell_manager.find_by_name_and_version_and_cpi @name, @version, cloud[:name]
            rescue StemcellNotFound => e
              stemcell = Models::Stemcell.new
              stemcell.name = @name
              stemcell.operating_system = @operating_system
              stemcell.version = @version
              stemcell.sha1 = @sha1
              stemcell.cpi = cloud[:name]
            end
          end

          needs_upload = @fix || !stemcell.cid
          upload_suffix = " (already exists, skipped)" unless needs_upload
          track_and_log("Uploading stemcell #{@name}/#{@version} to the cloud#{cpi_suffix}#{upload_suffix}") do
            if needs_upload
              stemcell.cid = cloud[:cpi].create_stemcell(@stemcell_image, @cloud_properties)
              logger.info("Cloud created stemcell#{cpi_suffix}: #{stemcell.cid}")
            else
              logger.info("Skipping stemcell upload, already exists#{cpi_suffix}")
            end
          end

          track_and_log("Save stemcell #{@name}/#{@version} (#{stemcell.cid})#{cpi_suffix}#{upload_suffix}") do
            if needs_upload
              stemcell.save
            else
              logger.info("Skipping stemcell save, already exists#{cpi_suffix}")
            end
          end
        end

        if stemcell.nil?
          raise StemcellNotSupported, "stemcell_formats of this stemcell are not supported by available cpis"
        else
          "/stemcells/#{stemcell.name}/#{stemcell.version}"
        end
      ensure
        FileUtils.rm_rf(stemcell_dir) if stemcell_dir
        FileUtils.rm_rf(@stemcell_path) if @stemcell_path
      end

      private

      def verify_sha1
        begin
          @multi_digest_verifier.verify(@stemcell_path, @stemcell_sha1)
        rescue Bosh::Director::Digest::ShaMismatchError => e
          raise Bosh::Director::StemcellSha1DoesNotMatch.new(e)
        end
      end

      def download_remote_stemcell
        download_remote_file('stemcell', @stemcell_url, @stemcell_path)
      end

      def update_steps
        steps = 2 # extract & verify manifest
        steps += 1 if @stemcell_url # also download remote stemcell
        steps += 1 if @stemcell_sha1 # also verify remote stemcell
        steps + cloud_factory.all_configured_clouds.count * 3 # check, upload and save for each cloud
      end

      def is_supported?(cloud)
        info = cloud[:cpi].info
        if @stemcell_formats && info["stemcell_formats"]
          return (info["stemcell_formats"] & @stemcell_formats).any?
        else
          logger.info("There is no enough information to check if stemcell format is supported")
          return true
        end
      rescue Bosh::Clouds::NotImplemented
        cpi_suffix = " (cpi: #{cloud[:name]})" unless cloud[:name].blank?
        logger.info("info method is not supported by cpi #{cpi_suffix}")
        return true
      end
    end
  end
end
