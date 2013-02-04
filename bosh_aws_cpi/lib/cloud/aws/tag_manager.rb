module Bosh::AwsCloud
  class TagManager

    MAX_TAG_KEY_LENGTH = 127
    MAX_TAG_VALUE_LENGTH = 255

    # Add a tag to something, make sure that the tag conforms to the
    # AWS limitation of 127 character key and 255 character value
    def self.tag(taggable, key, value)
      trimmed_key = key[0..(MAX_TAG_KEY_LENGTH - 1)]
      trimmed_value = value[0..(MAX_TAG_VALUE_LENGTH - 1)]
      taggable.add_tag(trimmed_key, :value => trimmed_value)
    rescue AWS::EC2::Errors::InvalidParameterValue => e
      @logger.error("could not tag #{taggable.id}: #{e.message}")
    end

  end
end
