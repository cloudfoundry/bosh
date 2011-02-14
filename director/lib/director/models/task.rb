module Bosh::Director::Models
  class Task < Sequel::Model
    def validate
      validates_presence [:state, :timestamp, :description]
    end
  end
end
