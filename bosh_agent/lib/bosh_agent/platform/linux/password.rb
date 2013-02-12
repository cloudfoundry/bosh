# Copyright (c) 2009-2012 VMware, Inc.
require 'bosh_agent/platform/linux'

module Bosh::Agent
  class Platform::Linux::Password

    def initialize
      @users ||= ['root', BOSH_APP_USER]
    end

    # Update passwords
    def update(settings)
      if bosh_settings = settings['env']['bosh']

        # TODO - also support user/password hash override
        if bosh_settings['password']
          @users.each do |user|
            update_password(user, bosh_settings['password'])
          end
        end

      end
    end

protected
    # Actually update password
    def update_password(user, encrypted_password)
      Bosh::Exec.sh "usermod -p '#{encrypted_password}' #{user} 2>%"
    end

  end
end
