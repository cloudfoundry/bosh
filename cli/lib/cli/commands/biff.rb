module Bosh::Cli::Command
  class Biff < Base

    # Takes your current deployment configuration and uses some of its
    # configuration to populate the template file.  The Network information is
    # used and then IPs for each job are automatically set.  Once the template
    # file has been used to generate a new config, the old config and new config
    # are diff'd and the user can choose to keep the new config.
    # @param [String] template The string path to the template that should be
    #     used.
    def biff(template)
      begin
        setup(template)

        template_to_fill = ERB.new(File.read(@template_file), 0, "%<>-")
        @template_output = template_to_fill.result(binding)

        if @errors == 0
          print_string_diff(File.read(@deployment_file), @template_output)
          keep_new_file unless @no_differences
        else
          say("There were " + "#{@errors} errors.".red)
        end
      ensure
        delete_temp_diff_files
      end
    end

    private

    # Unified is so that we get the whole file diff not just sections.
    DIFF_COMMAND = "diff --unified=1000"

    KEEP_NEW_VERSION_TEXT = "Would you like to keep the new version? [yn]"

    DIFF_FAILED_KEEP_NEW_TEXT =
        "Would you like the new version copied to '%s'? [yn]"

    # Accessor for testing purposes.
    attr_accessor :ip_helper, :template_output

    # Deletes the temporary files that were used.
    def delete_temp_diff_files
      # File.exists works for both files and directories.  Must use for 1.8
      # compat.
      if @dir_name && File.exists?(@dir_name)
        FileUtils.remove_entry_secure(@dir_name)
      end
    end

    # Takes two strings and prints the diff of them.
    # @param [String] str1 The first string to diff.
    # @param [String] str2 The string to diff against.
    def print_string_diff(str1, str2)
      File.open(@temp_file_path_1, "w") { |f| f.write(str1) }
      File.open(@temp_file_path_2, "w") { |f| f.write(str2) }

      @diff_works = true
      cmd = "#{DIFF_COMMAND} #{@temp_file_path_1} #{@temp_file_path_2} 2>&1"
      output = `#{cmd}`
      if $?.exitstatus == 2
        say("'#{cmd}' did not work.")
        say("Failed, saying: '#{output}'.")
        @diff_works = false
        return
      end

      if output.empty?
        output = "No differences."
        @no_differences = true
      end

      output.each_line do |line|
        added = line[0..0] == "+"
        removed = line[0..0] == "-"

        if added
          say(line.chomp.green)
        elsif removed
          say(line.chomp.red)
        else
          say(line)
        end
      end
    end

    # Alias for find.  It is used to find within a given object, not the default
    # deployment_obj
    # @param [String] path The path to the object that the template wants to
    #     retrieve from the user's config and substitute in.
    # @param [Object] obj Either a hash or array which is the user's deployment
    #     config to be looked through.
    # @return [Object] The found object.
    def find_in(path, obj)
      find(path, obj)
    end

    # Finds a path in the user's deployment configuration object.  The reason we
    # use this is to make the paths used in the template file better on the
    # eyes.  Instead of having find('jobs[4].static_ips') we have
    # find('jobs.debian_nfs_server.static_ips'). Find will look through the jobs
    # array and find the object that has name=debian_nfs_server.  If jobs were a
    # hash then find would get the hash key debian_nfs_server.
    # @param [String] path The path to the object that the template wants to
    #     retrieve from the user's config and substitute in.
    # @param [Object] obj Either a hash or array which is the user's deployment
    #     config to be looked through.
    # @return [Object] The found object.
    def find(path, obj = @deployment_obj)
      starting_obj = obj
      path_split = path.split(".")
      found_so_far = []
      path_split.each do |path_part|
        found = false
        if obj.is_a?(Array)
          obj.each do |data_val|
            if data_val["name"] == path_part
              obj = data_val
              found = true
            end
          end
        elsif !obj[path_part].nil?
          obj = obj[path_part]
          found = true
        end

        unless found
          @errors += 1
          say("Could not find #{path.red}.")
          say("'#{@template_file}' has it but '#{@deployment_file}' does not.")
          #say("\nIt should exist in \n#{obj.to_yaml}\n")
          if starting_obj == @deployment_obj
            # To cut down on complexity, we don't print out the section of code
            # from the template YAML that the user needs if the find method was
            # called with any other starting object other than deployment_obj.
            # The reason for this is because we'd have to recursively find the
            # path to the starting object so that it can be found in the
            # template.
            print_the_template_path(path.split('.'), found_so_far)
          end
          break
        end
        found_so_far << path_part
      end
      obj
    end

    # Used by print_the_template_path so that it can prettily print just the
    # section of the template that the user is missing.  E.x. if the user is
    # missing the job 'ccdb' then we want to not just print out 'ccdb' and
    # everything in it -- we also want to print out it's heirarchy, aka the fact
    # that it is under jobs.  So, we delete everything else in jobs.
    # @param [Object] obj Either a Hash or Array that is supposed to have
    #     everything deleted out of it except for a key or object with
    #     name = key depending on if it is a hash or array respectively.
    # @param [String] name They key to keep.
    # @return [Object] The original containing object with only the named object
    #     in it.
    def delete_all_except(obj, name)
      each_method = obj.is_a?(Hash) ? "each_key" : "each_index"
      obj.send(each_method) do |key|
        if key == name ||
           (obj[key].is_a?(Hash) && obj[key]["name"] == name)
          return_obj = nil
          if (obj.is_a?(Hash))
            return_obj = {}
            return_obj[name] = obj[key]
          else
            return_obj = [obj[key]]
          end
          return return_obj
        end
      end
    end

    # Tries to print out some helpful output from the template to let the user
    # know what they're missing.  For instance, if the user doesn't have a job
    # and the template needs to pull some data from the job then it will print
    # out what the job looks like in the template.  This method can't be used if
    # the path is a relative path.  A relative path is when find_in was used.
    # @param [Array] looking_for_path The path that is being looked for in the
    #     user's deployment config but does not exist.
    # @param [Array] users_farthest_found_path The farthest that 'find' got in
    #     finding the looking_for_path.
    def print_the_template_path(looking_for_path, users_farthest_found_path)
      delete_all_except_name =
          (looking_for_path - users_farthest_found_path).first
      path = users_farthest_found_path.join('.')
      what_we_need = find(path, @template_obj)
      what_we_need = delete_all_except(what_we_need, delete_all_except_name)
      say("Add this to '#{path}':".red + "\n#{what_we_need.to_yaml}\n\n")
    end

    # Loads the template file as YAML.  First, it replaces all of the ruby
    # syntax.  This file is used so that when there is an error, biff can report
    # what the user's deployment needs according to this template.
    # @return [String] The loaded template file as a ruby object.
    def load_template_as_yaml
      temp_data = File.read(@template_file)
      temp_data.gsub!(/<%=.*%>/, "INSERT_DATA_HERE")
      temp_data.gsub!(/[ ]*<%.*%>[ ]*\n/, "")
      YAML::load(temp_data)
    end

    # Gets the network's network/mask for configuring things such as the
    # nfs_server properties.  E.x. 192.168.1.0/22
    # @param [String] netw_name The name of the network to get the network/mast
    #     from.
    # @return [String] The network/mask.
    def get_network_and_mask(netw_name)
      netw_cidr = @ip_helper[netw_name]
      "#{netw_cidr.network}#{netw_cidr.netmask}"
    end

    # Used by the template to specify IPs for jobs. It uses the CIDR tool to get
    # them.
    # @param [Integer] ip_num The nth IP number to get.
    # @param [String] netw_name The name of the network to get the IP from.
    # @return [String] An IP in the network.
    def ip(ip_num, netw_name)
      ip_range((ip_num..ip_num), netw_name)
    end

    # Used by the template to specify IP ranges for jobs. It uses the CIDR tool
    # to get them.  Accepts negative ranges.
    # @param [Range] range The range of IPs to return, such as 10..24
    # @param [String] netw_name The name of the network to get the IPs from.
    # @return [String] An IP return in the network.
    def ip_range(range, netw_name)
      netw_cidr = @ip_helper[netw_name]
      first = (range.first >= 0) ? range.first :
          netw_cidr.size + range.first
      last = (range.last >= 0) ? range.last :
          netw_cidr.size + range.last

      first == last ? "#{netw_cidr.nth(first)}" :
          "#{netw_cidr.nth(first)} - #{netw_cidr.nth(last)}"
    end

    # Creates the helper hash.  Keys are the network name, values are the CIDR
    # tool for generating IPs for jobs in that network.
    # @return [Hash] The helper hash that has a CIDR instance for each network.
    def create_ip_helper
      helper = {}
      netw_arr = find("networks")
      if netw_arr.nil?
        raise "Must have a network section."
      end
      netw_arr.each do |netw|
        subnets = netw["subnets"]
        check_valid_network_config(netw, subnets)
        helper[netw["name"]] = NetAddr::CIDR.create(subnets.first["range"])
      end
      helper
    end

    # Raises errors if there is something wrong with the user's deployment
    # network configuration, since it's used to populate the rest of the
    # template.
    # @param [Hash] netw The user's network configuration as a ruby hash.
    # @param [Array] subnets The subnets in the network.
    def check_valid_network_config(netw, subnets)
      if subnets.nil?
        raise "You must have subnets in #{netw["name"]}"
      end
      unless subnets.length == 1
        raise "Biff doesn't know how to deal with anything other than one " +
              "subnet in #{netw["name"]}"
      end
      if subnets.first["range"].nil? || subnets.first["dns"].nil?
        raise "Biff requires each network to have range and dns entries."
      end
      if subnets.first["gateway"] && subnets.first["gateway"].match(/.*\.1$/).nil?
        raise "Biff only supports configurations where the gateway is the " +
              "first IP (e.g. 172.31.196.1)."
      end
    end

    # Asks if the user would like to keep the new template and copies it over
    # their existing template if yes.  This is its own function for testing.
    def keep_new_file
      copy_to_file = @diff_works ? @deployment_file : @deployment_file + ".new"
      agree_text = @diff_works ?
          KEEP_NEW_VERSION_TEXT : (DIFF_FAILED_KEEP_NEW_TEXT % copy_to_file)
      if agree(agree_text)
        say("New version copied to '#{copy_to_file}'")
        FileUtils.cp(@temp_file_path_2, copy_to_file)
      end
    end

    # Sets up a few instance variables.
    # @param [String] template The string path to the template that should be
    #     used.
    def setup(template)
      @template_file = template
      @deployment_file = deployment
      raise "Deployment not set." if @deployment_file.nil?
      @deployment_obj = load_yaml_file(@deployment_file)
      @template_obj = load_template_as_yaml
      @ip_helper = create_ip_helper
      @errors = 0
      @dir_name = Dir.mktmpdir
      @temp_file_path_1 = "#{@dir_name}/bosh_biff_1"
      @temp_file_path_2 = "#{@dir_name}/bosh_biff_2"
    end

  end
end
