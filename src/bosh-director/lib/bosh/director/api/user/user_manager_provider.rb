module Bosh::Director
  module Api
    class UserManagerProvider
      def user_manager(config_users)
        if config_users.nil? || config_users.empty?
          DatabaseUserManager.new
        else
          ConfigUserManager.new(config_users)
        end
      end
    end
  end
end
