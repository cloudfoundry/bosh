# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli::Command
  class CloudCheck < Base
    # bosh cloudcheck
    usage "cloudcheck"
    desc "Cloud consistency check and interactive repair"
    option "--auto",
           "resolve problems automatically ",
           "(not recommended for production)"
    option "--report",
           "generate report only, ",
           "don't attempt to resolve problems"
    def perform(deployment_name = nil)
      auth_required
      no_track_unsupported
      @auto_mode = options[:auto]
      @report_mode = options[:report]

      deployment_name ||= prepare_deployment_manifest(show_state: true).name

      if non_interactive? && !(@report_mode || @auto_mode)
        err ("Cloudcheck cannot be run in non-interactive mode\n" +
             "Please use `--auto' flag if you want automated resolutions " +
             "or `--report' if you just want a report of the errors")
      end

      if @auto_mode && @report_mode
        err("Can't use --auto and --report mode together")
      end


      say("Performing cloud check...")

      status, task_id = director.perform_cloud_scan(deployment_name)

      if status != :done
        task_report(status, task_id)
        exit(1)
      end

      nl
      say("Scan is complete, checking if any problems found...")
      @problems = director.list_problems(deployment_name)

      verify_problems
      nl
      say("Found #{pluralize(@problems.size, "problem")}".make_yellow)
      nl

      @resolutions = {}

      @problems.each_with_index do |problem, index|
        description = problem["description"].to_s.chomp(".") + "."
        say("Problem #{index+1} of #{@problems.size}: #{description}".make_yellow)
        next if @report_mode
        if @auto_mode
          @resolutions[problem["id"]] = {
            "name" => nil,
            "plan" => "apply default resolution"
          }
        else
          @resolutions[problem["id"]] = get_resolution(problem)
        end
        nl
      end

      if @report_mode
        exit(@problems.empty? ? 0 : 1)
      end

      confirm_resolutions unless @auto_mode
      say("Applying resolutions...")

      action_map = @resolutions.inject({}) do |hash, (id, resolution)|
        hash[id] = resolution["name"]
        hash
      end

      status, task_id = director.apply_resolutions(deployment_name, action_map)

      if status != :done
        task_report(status, task_id)
        exit(1)
      end

      say("Cloudcheck is finished".make_green)
    end

    private

    def verify_problems
      err("Invalid problem list format") unless @problems.kind_of?(Enumerable)

      if @problems.empty?
        say("No problems found".make_green)
        exit(0)
      end

      @problems.each do |problem|
        unless problem.is_a?(Hash) && problem["id"] && problem["description"] &&
            problem["resolutions"].kind_of?(Enumerable)
          err("Invalid problem list format received from director")
        end

        problem["resolutions"].each do |resolution|
          if resolution["name"].blank? || resolution["plan"].blank?
            err("Some problem resolutions received from director " +
                "have an invalid format")
          end
        end
      end
    end

    def get_resolution(problem)
      resolutions = problem["resolutions"]

      resolutions.each_with_index do |resolution, index|
        say("  #{index+1}. #{resolution["plan"]}")
      end

      choice = nil
      loop do
        choice = ask("Please choose a resolution [1 - #{resolutions.size}]: ")
        if choice =~ /^\s*\d+\s*$/ &&
            choice.to_i >= 1 &&
            choice.to_i <= resolutions.size
          break
        end
        say("Please enter a number between 1 and #{resolutions.size}".make_red)
      end

      resolutions[choice.to_i-1] # -1 accounts for 0-based indexing
    end

    def confirm_resolutions
      say("Below is the list of resolutions you've provided".make_yellow)
      say("Please make sure everything is fine and confirm your changes".make_yellow)
      nl

      @problems.each_with_index do |problem, index|
        plan = @resolutions[problem["id"]]["plan"]
        padding = " " * ((index+1).to_s.size + 4)
        say("  #{index+1}. #{problem["description"]}")
        say("#{padding}#{plan.to_s.make_yellow}")
        nl
      end

      cancel unless confirmed?("Apply resolutions?")
    end

    def cancel
      err("Canceled cloudcheck")
    end

  end
end
