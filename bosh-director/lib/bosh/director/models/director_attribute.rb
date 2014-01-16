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

    def self.update_or_create_uuid(value, logger)
      if where(name: 'uuid').update(value: value) == 0
        create(name: 'uuid', value: value)
        logger.info("Created uuid director attribute with value=#{value.inspect}")
      else
        logger.info("Updated uuid director attribute with value=#{value.inspect}")
      end
      value
    end
  end
end
