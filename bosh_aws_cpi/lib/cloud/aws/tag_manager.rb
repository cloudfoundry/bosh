module Bosh::AwsCloud
  class TagManager

    MAX_TAG_KEY_LENGTH = 127
    MAX_TAG_VALUE_LENGTH = 255

    # Add a tag to something, make sure that the tag conforms to the
    # AWS limitation of 127 character key and 255 character value
    def self.tag(taggable, key, value)
      return if key.nil? || value.nil?
      trimmed_key = key.to_s.slice(0, MAX_TAG_KEY_LENGTH)
      trimmed_value = value.to_s.slice(0, MAX_TAG_VALUE_LENGTH)
      taggable.add_tag(trimmed_key, :value => trimmed_value)
    rescue AWS::EC2::Errors::InvalidParameterValue => e
      logger.error("could not tag #{taggable.id}: #{e.message}")
    rescue AWS::EC2::Errors::InvalidAMIID::NotFound,
        AWS::EC2::Errors::InvalidInstanceID::NotFound=> e
      # Due to the AWS eventual consistency, the taggable might not
      # be there, even though we previous have waited until it is,
      # so we wait again...
      logger.warn("tagged object doesn't exist: #{taggable.id}")
      sleep(1)
      retry
    end

    def self.logger
      Bosh::Clouds::Config.logger
    end
  end
end
