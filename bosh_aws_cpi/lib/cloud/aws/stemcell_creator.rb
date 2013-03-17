module Bosh::AwsCloud
  class StemcellCreator
    include Bosh::Exec
    include Helpers

    attr_reader :region, :stemcell_properties
    attr_reader :volume, :ebs_volume, :image_path

    def initialize(region, stemcell_properties)
      @region = region
      @stemcell_properties = stemcell_properties
    end

    def create(volume, ebs_volume, image_path)
      @volume = volume
      @ebs_volume = ebs_volume
      @image_path = image_path

      copy_root_image

      snapshot = volume.create_snapshot
      ResourceWait.for_snapshot(snapshot: snapshot, state: :completed)

      params = image_params(snapshot.id)
      image = region.images.create(params)
      ResourceWait.for_image(image: image, state: :available)

      TagManager.tag(image, 'Name', params[:description]) if params[:description]

      Stemcell.new(region, image)
    end

    def fake?
      stemcell_properties.has_key?('ami')
    end

    def fake
      id = stemcell_properties['ami'][region.name]

      raise Bosh::Clouds::CloudError, 'Stemcell does not contain an AMI for this region' unless id

      Stemcell.find(region, id)
    end

    # This method tries to execute the helper script stemcell-copy
    # as root using sudo, since it needs to write to the ebs_volume.
    # If stemcell-copy isn't available, it falls back to writing directly
    # to the device, which is used in the micro bosh deployer.
    # The stemcell-copy script must be in the PATH of the user running
    # the director, and needs sudo privileges to execute without
    # password.
    #
    # TODO we require sudo to write to the EBS volume device.
    #  Luckly on aws ubuntu we have passwordless sudo for everything
    #  We should really fix this so we either don't need sudo or give
    #   the user more warning / explanation for the
    #   possible sudo password prompt
    def copy_root_image
      stemcell_copy = find_in_path("stemcell-copy")

      if stemcell_copy
        logger.debug("copying stemcell using stemcell-copy script")
        # note that is is a potentially dangerous operation, but as the
        # stemcell-copy script sets PATH to a sane value this is safe
        command = "sudo -n #{stemcell_copy} #{image_path} #{ebs_volume} 2>&1"
      else
        logger.info("falling back to using included copy stemcell")
        included_stemcell_copy = File.expand_path("../../../../scripts/stemcell-copy.sh", __FILE__)
        command = "sudo -n #{included_stemcell_copy} #{image_path} #{ebs_volume} 2>&1"
      end

      result = sh(command)

      logger.debug("stemcell copy output:\n#{result.output}")
    rescue Bosh::Exec::Error => e
      raise Bosh::Clouds::CloudError, "Unable to copy stemcell root image: #{e.message}"
    end

    # checks if the stemcell-copy script can be found in
    # the current PATH
    def find_in_path(command, path=ENV["PATH"])
      path.split(":").each do |dir|
        stemcell_copy = File.join(dir, command)
        return stemcell_copy if File.exist?(stemcell_copy)
      end
      nil
    end

    def image_params(snapshot_id)
      root_device_name = stemcell_properties["root_device_name"]
      architecture = stemcell_properties["architecture"]

      aki = AKIPicker.new(region).pick(architecture, root_device_name)

      params = {
          :name => "BOSH-#{SecureRandom.uuid}",
          :architecture => architecture,
          :kernel_id => aki,
          :root_device_name => root_device_name,
          :block_device_mappings => {
              "/dev/sda" => {:snapshot_id => snapshot_id},
              "/dev/sdb" => "ephemeral0"
          }
      }

      # old stemcells doesn't have name & version
      if stemcell_properties["name"] && stemcell_properties["version"]
        name = "#{stemcell_properties['name']} #{stemcell_properties['version']}"
        params[:description] = name
      end

      params
    end

    def logger
      Bosh::Clouds::Config.logger
    end
  end
end
