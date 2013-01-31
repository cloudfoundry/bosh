module Bosh::AwsCloud
  class Stemcell
    attr_reader :aws_ami

    def self.find(region, id)
      image = region.images[id]
      raise Bosh::Clouds::CloudError, "could not find AMI #{id}" unless image.exists?
      new(image)
    end

    def initialize(image)
      @aws_ami = image
    end

    def root_device_name
      aws_ami.root_device_name
    end
  end
end
