module Bosh::Agent
  class Platform::Ubuntu::Password

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
      output = `usermod -p '#{password}' #{user} 2>%`
      exit_code = $?.exitstatus
      unless exit_code == 0
        raise Bosh::Agent::FatalError, "Failed set passsword for #{user} (#{exit_code}: #{output})"
      end
    end

  end
end
