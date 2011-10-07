module Bosh::Director::Models
  class ReleaseProperty < Sequel::Model

    VALID_PROPERTY_NAME = /^[-a-z0-9_.]+$/i

    many_to_one :release

    def validate
      validates_presence :release_id
      validates_presence :name
      validates_presence :value

      validates_unique [:name, :release_id]

      validates_format VALID_PROPERTY_NAME, :name, :allow_blank => true
    end

  end
end
