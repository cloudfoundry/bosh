module Bosh::Director::Models
  class DirectorAttribute < Sequel::Model(Bosh::Director::Config.db)
    def validate
      validates_presence :name
    end

    def self.find_or_create_uuid(logger)
      uuid = first(name: 'uuid')
      if uuid
        logger.info("Found uuid director attribute with value=#{uuid.value.inspect}")
        return uuid.value
      end

      begin
        uuid = create(name: 'uuid', value: SecureRandom.uuid)
        logger.info("Created uuid director attribute with value=#{uuid.value.inspect}")
        uuid.value
      rescue Sequel::DatabaseError => e
        # Database will throw an error in case of race condition
        # causing multiple uuid records being inserted
        logger.info("Failed to create uuid director attribute e=#{e.inspect}\n#{e.backtrace}")

        uuid = first(name: 'uuid')
        logger.info("Found uuid director attribute with value=#{uuid.value.inspect}")
        uuid.value
      end
    end

    def self.uuid
      uuid = first(name: 'uuid')
      return uuid.value if uuid
    end

    def self.set_attribute(attr_name, attr_value)
      create(name: attr_name, value: attr_value.to_s)
    rescue Sequel::ValidationFailed, Sequel::DatabaseError => e
      error_message = e.message.downcase
      if error_message.include?('unique') || error_message.include?('duplicate')
        where(name: attr_name).update(value: attr_value.to_s)
      else
        raise e
      end
    end

    def self.get_attribute(attr_name)
      record = first(name: attr_name)
      record.nil? || record.value == "false" ? false : true
    end
  end
end
