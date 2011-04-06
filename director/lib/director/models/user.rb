  module Bosh::Director::Models
  class User < Sequel::Model
    def validate
      validates_presence :username
      validates_presence :password
      validates_unique :username
    end
  end
end
