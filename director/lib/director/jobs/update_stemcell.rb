module Bosh::Director

  module Jobs

    class UpdateStemcell
      include ValidationHelper

      @queue = :normal

      def self.perform(task_id, stemcell_file)
        UpdateStemcell.new(task_id, stemcell_file).perform
      end

      def initialize(task_id, stemcell_file)
        task_status_file = File.join(Config.base_dir, "tasks", task_id.to_s)
        FileUtils.mkdir_p(File.dirname(task_status_file))
        @logger = Logger.new(task_status_file)
        @logger.level= Config.logger.level
        Config.logger = @logger

        @task = Models::Task[task_id]
        raise Bosh::Director::TaskNotFound if @task.nil?

        @task.output = task_status_file
        @task.save!

        @stemcell_file = stemcell_file
        @cloud = Config.cloud
      end

      def perform
        @logger.info("Processing update stemcell")

        @task.state = :processing
        @task.timestamp = Time.now.to_i
        @task.save!

        stemcell_dir = Dir.mktmpdir("stemcell")

        begin
          @logger.info("Extracting stemcell archive")
          output = `tar -C #{stemcell_dir} -xzf #{@stemcell_file} 2>&1`
          raise Bosh::Director::StemcellInvalidArchive.new($?.exitstatus, output) if $?.exitstatus != 0

          @logger.info("Verifying stemcell manifest")
          stemcell_manifest_file = File.join(stemcell_dir, "stemcell.MF")
          stemcell_manifest = YAML.load_file(stemcell_manifest_file)

          @name = safe_property(stemcell_manifest, "name", :class => String)
          @version = safe_property(stemcell_manifest, "version", :class => Integer)
          @cloud_properties = safe_property(stemcell_manifest, "cloud_properties", :class => Hash, :optional => true)
          @stemcell_image = File.join(stemcell_dir, "image")

          @logger.info("Verifying stemcell image")
          raise Bosh::Director::StemcellInvalidImage unless File.file?(@stemcell_image)

          @logger.info("Uploading stemcell to the cloud")
          cid = @cloud.create_stemcell(@stemcell_image, @cloud_properties)
          @logger.info("Cloud created stemcell: #{cid}")

          stemcell = Models::Stemcell.new
          stemcell.name = @name
          stemcell.version = @version
          stemcell.cid = cid
          stemcell.save!

          @logger.info("Done")

          @task.state = :done
          @task.timestamp = Time.now.to_i
          @task.save!
        rescue Exception => e
          @logger.error("#{e} - #{e.backtrace.join("\n")}")
          @task.state = :error
          @task.result = e.to_s
          @task.timestamp = Time.now.to_i
          @task.save!
        ensure
          FileUtils.rm_rf(stemcell_dir)
          FileUtils.rm_rf(@stemcell_file)
        end
      end

    end
  end
end
