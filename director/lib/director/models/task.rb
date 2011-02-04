module Bosh::Director::Models
  class Task < Ohm::Model
    attribute :state
    attribute :description
    attribute :timestamp
    attribute :result
    attribute :output

    index :state
    index :timestamp

    def validate
      assert_present :state
      assert_present :timestamp
    end
  end
end
