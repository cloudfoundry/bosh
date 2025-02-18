require 'securerandom'

module Bosh::Director
  module Jobs
    class UpdateStemcell < BaseJob
      include Bosh::Director::LockHelper
      include ValidationHelper
      include DownloadHelper
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

        @stemcell_sha1 = options['sha1'] if options['sha1']

        @multi_digest_verifier = BoshDigest::MultiDigest.new(logger)
        @stemcell_manager = Api::StemcellManager.new
        @fix = options['fix']
      end

      def perform
        logger.info('Processing update stemcell')

        # adjust numbers in update_steps if you change how many times `track_and_log` are invoked below.
        begin_stage('Update stemcell', update_steps)

        track_and_log('Downloading remote stemcell') { download_remote_stemcell } if @stemcell_url

        stemcell_dir = Dir.mktmpdir('stemcell')

        track_and_log('Verifying remote stemcell') { verify_sha1 } if @stemcell_sha1

        track_and_log('Extracting stemcell archive') do
          result = Bosh::Common::Exec.sh("tar -C #{stemcell_dir} -xzf #{@stemcell_path} 2>&1", on_error: :return)
          if result.failed?
            logger.error("Extracting stemcell archive failed in dir #{stemcell_dir}, " \
                         "tar returned #{result.exit_status}, " \
                         "output: #{result.output}")
            raise StemcellInvalidArchive, 'Extracting stemcell archive failed. Check task debug log for details.'
          end
        end

        track_and_log('Verifying stemcell manifest') do
          stemcell_manifest_file = File.join(stemcell_dir, 'stemcell.MF')
          stemcell_manifest = YAML.load_file(stemcell_manifest_file, aliases: true)

          @name = safe_property(stemcell_manifest, 'name', class: String)
          @operating_system = safe_property(stemcell_manifest, 'operating_system', class: String, optional: true, default: @name)
          @version = safe_property(stemcell_manifest, 'version', class: String)
          @stemcell_formats = safe_property(stemcell_manifest, 'stemcell_formats', class: Array, optional: true)
          @cloud_properties = safe_property(stemcell_manifest, 'cloud_properties', class: Hash, optional: true)
          @sha1 = safe_property(stemcell_manifest, 'sha1', class: String)
          @api_version = safe_property(stemcell_manifest, 'api_version', class: Integer, optional: true)

          logger.info("Found stemcell image '#{@name}/#{@version}', " \
                      "cloud properties are #{@cloud_properties.inspect}")

          logger.info('Verifying stemcell image')
          @stemcell_image = File.join(stemcell_dir, 'image')
          raise StemcellImageNotFound, 'Stemcell image not found' unless File.file?(@stemcell_image)
        end

        stemcell = nil
        cloud_factory = CloudFactory.create
        with_stemcell_lock(@name, @version, timeout: 900 * cloud_factory.all_names.length) do
          cloud_factory.all_names.each do |cpi|
            cloud = cloud_factory.get(cpi)
            cpi_suffix = " (cpi: #{cpi})" unless cpi.blank?

            unless is_supported?(cloud, cpi)
              logger.info("#{cpi_suffix} cpi does not support stemcell format")
              Models::StemcellUpload.find_or_create(
                name: @name,
                cpi: cpi,
                version: @version,
              )
              next
            end

            track_and_log("Checking if this stemcell already exists#{cpi_suffix}") do
              begin
                stemcell = @stemcell_manager.find_by_name_and_version_and_cpi(@name, @version, cpi)
              rescue StemcellNotFound
                stemcell = Models::Stemcell.new
                stemcell.name = @name
                stemcell.operating_system = @operating_system
                stemcell.version = @version
                stemcell.sha1 = @sha1
                stemcell.cpi = cpi
                stemcell.api_version = @api_version
              end
            end

            needs_upload = @fix || !stemcell.cid
            upload_suffix = ' (already exists, skipped)' unless needs_upload
            track_and_log("Uploading stemcell #{@name}/#{@version} to the cloud#{cpi_suffix}#{upload_suffix}") do
              if needs_upload
                tags = get_tags()
                stemcell.cid = cloud.create_stemcell(@stemcell_image, @cloud_properties, {"tags" => tags})
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

            Models::StemcellUpload.find_or_create(
              name: @name,
              cpi: cpi,
              version: @version,
            )
          end
        end

        if stemcell.nil?
          all_cpi_formats = cloud_factory.all_names.flat_map { |cpi| cloud_factory.get(cpi).info['stemcell_formats'] }.uniq
          err_message = 'uploaded stemcell with formats %s are not supported by available cpi formats: %s'
          raise StemcellNotSupported, format(err_message, @stemcell_formats, all_cpi_formats)
        else
          "/stemcells/#{stemcell.name}/#{stemcell.version}"
        end
      ensure
        FileUtils.rm_rf(stemcell_dir) if stemcell_dir
        FileUtils.rm_rf(@stemcell_path) if @stemcell_path
      end

      private

      def get_tags()
        tags = {}
        runtime_configs = Bosh::Director::Api::RuntimeConfigManager.new.list(1, "default")
        if !runtime_configs.nil? && !runtime_configs[0].nil?
          raw = runtime_configs[0]
          if !raw.nil? 
            hash = raw.to_hash
            tags.merge!(hash["tags"])
          end
        end
        return tags
      end

      def verify_sha1
        @multi_digest_verifier.verify(@stemcell_path, @stemcell_sha1)
      rescue Bosh::Director::BoshDigest::ShaMismatchError => e
        raise Bosh::Director::StemcellSha1DoesNotMatch, e
      end

      def download_remote_stemcell
        download_remote_file('stemcell', @stemcell_url, @stemcell_path)
      end

      def update_steps
        steps = 2 # extract & verify manifest
        steps += 1 if @stemcell_url # also download remote stemcell
        steps += 1 if @stemcell_sha1 # also verify remote stemcell
        steps + CloudFactory.create.all_names.count * 3 # check, upload and save for each cloud
      end

      def is_supported?(cloud, cpi)
        info = cloud.info
        return (info['stemcell_formats'] & @stemcell_formats).any? if @stemcell_formats && info['stemcell_formats']

        logger.info('There is no enough information to check if stemcell format is supported')
        true
      rescue Bosh::Clouds::NotImplemented
        cpi_suffix = " (cpi: #{cpi})" unless cpi.blank?
        logger.info("info method is not supported by cpi #{cpi_suffix}")
        return true
      end
    end
  end
end
