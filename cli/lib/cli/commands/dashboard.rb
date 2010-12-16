module Bosh::Cli::Command
  class Dashboard < Base

    def version
      say("Bosh %s" % [ Bosh::Cli::VERSION ])
    end

    def status
      say("Target:     %s" % [ target || "not set" ])
      say("User:       %s" % [ logged_in? ? username : "not set" ])
      say("Deployment: %s" % [ deployment || "not set" ])
    end

    def login(username = nil, password = nil)
      err("Please choose target first") if target.nil?

      unless options[:non_interactive]      
        username = ask("Your username: ") if username.blank?

        password_retries = 0
        while password.blank? && password_retries < 3
          password = ask("Enter password: ") { |q| q.echo = "*" }
          password_retries += 1
        end
      end

      err("Please provide username and password") if username.blank? || password.blank?

      if options[:director_checks]
        director = Bosh::Cli::Director.new(target, username, password)
        
        if director.authenticated?
          say("Logged in as '#{username}'")          
        else
          say("Cannot log in as '#{username}', please try again")
          return login(username, nil) unless options[:non_interactive]
        end
      end

      config.set_credentials(target, username, password)
      config.save
    end

    def logout
      err("Please choose target first") unless target
      config.set_credentials(target, nil, nil)
      config.save
      say("You are no longer logged in to '#{target}'")
    end

    def purge_cache
      if cache.cache_dir != DEFAULT_CACHE_DIR
        say("Cache directory '#{@cache.cache_dir}' differs from default, please remove manually")
      else
        FileUtils.rm_rf(cache.cache_dir)
        say("Purged cache")          
      end      
    end

    def show_target
      say(target ? "Current target is '#{target}'" : "Target not set")
    end

    def set_target(director_url)
      director = Bosh::Cli::Director.new(director_url)
      
      if options[:director_checks] && !director.exists?
        err("Cannot talk to director at '#{director_url}', please set correct target")
      end

      config.target = director_url

      if deployment
        say("WARNING! Your deployment has been unset")
        config.deployment = nil
      end
      
      config.save
      say("Target set to '#{director_url}'")
    end

  end
end
