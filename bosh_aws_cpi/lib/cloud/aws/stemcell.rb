module Bosh::AwsCloud
  class Stemcell
    include Helpers

    attr_reader :ami, :snapshots

    def self.find(region, id)
      image = region.images[id]
      raise Bosh::Clouds::CloudError, "could not find AMI '#{id}'" unless image.exists?
      new(region, image)
    end

    def initialize(region, image)
      @region = region
      @ami = image
      @snapshots = []
    end

    def delete
      memoize_snapshots

      ami.deregister

      # Wait for the AMI to be deregistered, or the snapshot deletion will fail,
      # as the AMI is still in use.
      ResourceWait.for_image(image: ami, state: :deleted)

      delete_snapshots
      logger.info("deleted stemcell '#{id}'")
    # The following suppression of AuthFailure is potentially dangerous
    # But we have to do it here because we need to be compatible with existing
    # light stemcells in BOSH DB which appear to be "heavy".
    rescue AWS::EC2::Errors::AuthFailure => e
      # If we get an auth failure from the deregister call, it means we don't own the AMI
      # and we were just faking it, so we can just return pretending that we deleted it.
      logger.info("deleted fake stemcell '#{id}")
    end

    def id
      ami.id
    end

    def image_id
      ami.id
    end

    def root_device_name
      ami.root_device_name
    end

    def memoize_snapshots
      # .to_hash is used as the AWS API documentation isn't trustworthy:
      # it says block_device_mappings retruns a Hash, but in reality it flattens it!
      ami.block_device_mappings.to_hash.each do |device, map|
        snapshot_id = map[:snapshot_id]
        if id
          logger.debug("queuing snapshot '#{snapshot_id}' for deletion")
          snapshots << snapshot_id
        end
      end
    end

    def delete_snapshots
      snapshots.each do |id|
        logger.info("cleaning up snapshot '#{id}'")
        snapshot = @region.snapshots[id]
        snapshot.delete
      end
    end

    def logger
      Bosh::Clouds::Config.logger
    end
  end
end
