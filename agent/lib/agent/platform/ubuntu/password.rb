module Bosh::Agent
  class Platform::Ubuntu::Password
    include Bosh::Exec

    def update(settings)
      if bosh_settings = settings['env']['bosh']

        # TODO - also support user/password hash override
        if bosh_settings['password']
          update_passwords(bosh_settings['password'])
        end

      end
    end

    def update_passwords(password)
      [ 'root', BOSH_APP_USER ].each do |user|
        update_password(user, password)
      end
    end

    # "mkpasswd -m sha-512" to mimick default LTS passwords
    def update_password(user, password)
      result = sh("usermod -p '#{password}' #{user} 2>&1")
      unless result.ok?
        raise Bosh::Agent::FatalError, "Failed set passsword for #{user} (#{result.status}: #{result.stdout})"
      end
    end

  end
end
