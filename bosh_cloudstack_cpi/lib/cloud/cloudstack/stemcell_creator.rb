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

      snapshot_response = volume.service.create_snapshot({:volumeid => volume.id})
      snapshot_job = volume.service.jobs.get(snapshot_response["createsnapshotresponse"]["jobid"])
      wait_job(snapshot_job)

      params = image_params(snapshot_job.job_result["snapshot"]["id"])
      template_response = volume.service.create_template(params)
      template_job = volume.service.jobs.get(template_response["createtemplateresponse"]["jobid"])
      wait_job(template_job)

      TagManager.tag(
        volume.service.images.get(template_job.job_result["template"]["id"]),
        'Name',
        params[:displaytext])
      image = volume.service.images.get(template_job.job_result["template"]["id"])
      image
    end


    def fake?
      stemcell_properties.has_key?('ami')
    end

    def fake
      id = stemcell_properties['ami'][region.name]

      raise Bosh::Clouds::CloudError, "Stemcell does not contain an AMI for this region (#{region.name})" unless id

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
    def copy_root_image
      stemcell_copy = find_in_path("stemcell-copy")
      if stemcell_copy
        logger.debug("copying stemcell using stemcell-copy script")
        # note that is is a potentially dangerous operation, but as the
        # stemcell-copy script sets PATH to a sane value this is safe
        command = "sudo -n #{stemcell_copy} #{image_path} #{device} 2>&1"
      else
        logger.info("falling back to using included copy stemcell")
        included_stemcell_copy = File.expand_path("../../../../scripts/stemcell-copy.sh", __FILE__)
        command = "sudo -n #{included_stemcell_copy} #{image_path} #{device} 2>&1"
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
      architecture_bit = {"x86" => "32", "x86_64" => "64"}[stemcell_properties["architecture"]]
      os_type = cloud.compute.list_os_types["listostypesresponse"]["ostype"].find do |os_type|
        os_type["description"] == "Ubuntu 10.04 (64-bit)"
#        os_type["description"].match(/Other Ubuntu \(#{architecture_bit}-bit\)/i)
      end

      params = {
          :displaytext => "#{stemcell_properties["name"]} #{stemcell_properties["version"]}",
          :name => "BOSH-#{SecureRandom.hex(8)}", # less than 32 characters
          :ostypeid => os_type["id"],
          :snapshotid => snapshot_id,
      }

      params
    end

    def logger
      Bosh::Clouds::Config.logger
    end
  end
end
