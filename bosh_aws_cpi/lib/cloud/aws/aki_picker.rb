module Bosh::AwsCloud
  class AKIPicker

    # @param [AWS::Core::ServiceInterface] region
    def initialize(region)
      @region = region
    end

    # finds the correct aki for the current region
    # @param [String] architecture instruction architecture to find
    # @param [String] root_device_name
    # @return [String] EC2 image id
    def pick(architecture, root_device_name)
      candidate = pick_candidate(fetch_akis(architecture), root_device_name)
      raise Bosh::Clouds::CloudError, "unable to find AKI" unless candidate
      logger.info("auto-selected AKI: #{candidate.image_id}")

      candidate.image_id
    end

    private

    def fetch_akis(architecture)
      filter = aki_filter(architecture)
      @region.client.describe_images(filters: filter).images_set
    end

    # @return [Hash] search filter
    def aki_filter(architecture)
      [
          {name: "architecture", values: [architecture]},
          {name: "image-type", values: %w[kernel]},
          {name: "owner-alias", values: %w[amazon]}
      ]
    end

    def regexp(root_device_name)
      # do nasty hackery to select boot device and version from
      # the image_location string e.g. pv-grub-hd00_1.03-x86_64.gz
      if root_device_name == "/dev/sda1"
        /-hd00[-_](\d+)\.(\d+)/
      else
        /-hd0[-_](\d+)\.(\d+)/
      end
    end

    # @param [AWS::EC2::ImageCollection] akis
    def pick_candidate(akis, root_device_name)
      candidate = nil
      major = 0
      minor = 0
      akis.each do |image|
        match = image.image_location.match(regexp(root_device_name))
        if match && match[1].to_i > major && match[2].to_i > minor
          candidate = image
          major = match[1].to_i
          minor = match[2].to_i
        end
      end

      candidate
    end

    def logger
      Bosh::Clouds::Config.logger
    end
  end
end
