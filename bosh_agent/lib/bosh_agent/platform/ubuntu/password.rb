# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent
  class Platform::Ubuntu::Password

    def update(settings)      
      # TODO - also support user/password hash override
      if settings['env'] && settings['env']['bosh'] && settings['env']['bosh']['password']
        update_passwords(settings['env']['bosh']['password'])
      end
    end

    def update_passwords(password)
      [ 'root', BOSH_APP_USER ].each do |user|
        update_password(user, password)
      end
    end

    # "mkpasswd -m sha-512" to mimick default LTS passwords
    def update_password(user, password)
      output = `usermod -p '#{password}' #{user} 2>%`
      exit_code = $?.exitstatus
      unless exit_code == 0
        raise Bosh::Agent::FatalError, "Failed set passsword for #{user} (#{exit_code}: #{output})"
      end
    end

  end
end
