module Bosh::CloudStackCloud
  class StemcellCreator
    include Bosh::Exec
    include Helpers

    attr_reader :zone, :stemcell_properties, :cloud
    attr_reader :volume, :device, :image_path

    def initialize(zone, stemcell_properties, cloud)
      @zone = zone
      @stemcell_properties = stemcell_properties
      @cloud = cloud
      @state_timeout = cloud.state_timeout
      @state_timeout_volume = cloud.state_timeout_volume
    end

    def create(volume, device, image_path)
      @volume = volume
      @device = device
      @image_path = image_path

      copy_root_image
      # need updating Fog
      # taking a snapshot of attached volumes causes serious performance problem in some envinronments
      volume.reload
      cloud.detach_volume(volume.server, volume)

      snapshot = volume.service.snapshots.create({:volume_id => volume.id})
      wait_resource(snapshot, :backedup, :state, false, @state_timeout_volume)

      # TODO create fog model
      params = image_params(snapshot.id, volume.service)
      template_response = volume.service.create_template(params)
      template_job = volume.service.jobs.get(template_response["createtemplateresponse"]["jobid"])
      wait_job_volume(template_job)

      snapshot.destroy

      image = volume.service.images.get(template_job.job_result["template"]["id"])
      TagManager.tag(
        image,
        'Name',
        params[:displaytext])
      image
    end


    # This method tries to execute the helper script stemcell-copy
    # as root using sudo, since it needs to write to the ebs_volume.
    # If stemcell-copy isn't available, it falls back to writing directly
    # to the device, which is used in the micro bosh deployer.
    # The stemcell-copy script must be in the PATH of the user running
    # the director, and needs sudo privileges to execute without
    # password.
    #
    def copy_root_image
      stemcell_copy = find_in_path("stemcell-copy-cloudstack")
      if stemcell_copy
        logger.debug("copying stemcell using stemcell-copy-cloudstack script")
        # note that is is a potentially dangerous operation, but as the
        # stemcell-copy script sets PATH to a sane value this is safe
        command = "sudo -n #{stemcell_copy} #{image_path} #{device} 2>&1"
      else
        logger.info("falling back to using included copy stemcell")
        included_stemcell_copy = File.expand_path("../../../../scripts/stemcell-copy-cloudstack.sh", __FILE__)
        command = "sudo -n #{included_stemcell_copy} #{image_path} #{device} 2>&1"
      end

      result = sh(command)
      logger.debug("stemcell copy output:\n#{result.output}")
    rescue Bosh::Exec::Error => e
      raise Bosh::Clouds::CloudError, "Unable to copy stemcell root image: #{e.message};  #{e.output}"
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

    def image_params(snapshot_id, compute)
      architecture_bit = {"x86" => "32", "x86_64" => "64"}[stemcell_properties["architecture"]]
      ostype = compute.ostypes.find do |ostype|
        ostype.description == "Ubuntu 10.04 (64-bit)"
      end

      params = {
          :displaytext => "#{stemcell_properties["name"]} #{stemcell_properties["version"]}",
          :name => "BOSH-#{SecureRandom.hex(8)}", # less than 32 characters
          :ostypeid => ostype.id,
          :snapshotid => snapshot_id,
      }

      params
    end

    def logger
      Bosh::Clouds::Config.logger
    end
  end
end
