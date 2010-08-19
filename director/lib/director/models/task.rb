module Bosh::Director::Models
  class Task < Ohm::Model
    attribute :state
    attribute :timestamp
    attribute :result
    attribute :output
    list :events

    def validate
      assert_present :state
      assert_present :timestamp
    end
  end
end
