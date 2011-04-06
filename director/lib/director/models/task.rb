module Bosh::Director::Models
  class Task < Sequel::Model
    many_to_one  :user
    def validate
      validates_presence [:state, :timestamp, :description]
    end
  end
end
