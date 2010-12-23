module Bosh::Director
  module Jobs
    class UpdateStemcell
      extend BaseJob
      include ValidationHelper

      @queue = :normal

      def initialize(stemcell_file)
        @stemcell_file = stemcell_file
        @cloud = Config.cloud
        @logger = Config.logger
      end

      def perform
        @logger.info("Processing update stemcell")

        stemcell_dir = Dir.mktmpdir("stemcell")

        @logger.info("Extracting stemcell archive")
        output = `tar -C #{stemcell_dir} -xzf #{@stemcell_file} 2>&1`

        raise StemcellInvalidArchive.new($?.exitstatus, output) if $?.exitstatus != 0

        @logger.info("Verifying stemcell manifest")
        stemcell_manifest_file = File.join(stemcell_dir, "stemcell.MF")
        stemcell_manifest = YAML.load_file(stemcell_manifest_file)

        @name = safe_property(stemcell_manifest, "name", :class => String)
        @version = safe_property(stemcell_manifest, "version", :class => String)
        @cloud_properties = safe_property(stemcell_manifest, "cloud_properties", :class => Hash, :optional => true)
        @stemcell_image = File.join(stemcell_dir, "image")
        @logger.info("Found: name=>#{@name}, version=>#{@version}, cloud_properties=>#{@cloud_properties}")

        @logger.info("Verifying stemcell image")
        raise StemcellInvalidImage unless File.file?(@stemcell_image)

        @logger.info("Checking if this stemcell already exists")
        stemcells = Models::Stemcell.find(:name => @name, :version => @version)
        raise StemcellAlreadyExists.new(@name, @version) unless stemcells.empty?

        @logger.info("Uploading stemcell to the cloud")
        cid = @cloud.create_stemcell(@stemcell_image, @cloud_properties)
        @logger.info("Cloud created stemcell: #{cid}")

        stemcell = Models::Stemcell.new
        stemcell.name = @name
        stemcell.version = @version
        stemcell.cid = cid
        stemcell.save!
        "/stemcells/#{stemcell.name}"
      ensure
        FileUtils.rm_rf(stemcell_dir) if stemcell_dir
        FileUtils.rm_rf(@stemcell_file) if @stemcell_file
      end

    end
  end
end
