# Copyright (c) 2012 VMware, Inc.
require 'tmpdir'

module Bat
  module DeploymentHelper
    def stemcell
      @stemcell ||= Bat::Stemcell.from_path(BoshHelper.read_environment('BAT_STEMCELL'))
    end

    def release
      @release ||= Bat::Release.from_path(BAT_RELEASE_DIR)
    end

    def previous_release
      @previous_release ||= release.previous
    end

    def deployment
      load_deployment_spec
      @deployment ||= Bat::Deployment.new(@spec)
    end

    # @return [Array[String]]
    def deployments
      result = {}
      jbosh('/deployments').each { |d| result[d['name']] = d }
      result
    end

    def releases
      result = []
      jbosh('/releases').each do |r|
        result << Bat::Release.new(r['name'], r['release_versions'].map { |v| v['version'] })
      end
      result
    end

    def stemcells
      result = []
      jbosh('/stemcells').each do |s|
        result << Bat::Stemcell.new(s['name'], s['version'])
      end
      result
    end

    def requirement(what, present = true)
      case what
        when Bat::Stemcell
          if stemcells.include?(stemcell)
            puts 'stemcell already uploaded'
          else
            puts 'stemcell not uploaded'
            bosh_safe("upload stemcell #{what.to_path}").should succeed
          end
        when Bat::Release
          if releases.include?(release)
            puts 'release already uploaded'
          else
            puts 'release not uploaded'
            bosh_safe("upload release #{what.to_path}").should succeed
          end
        when Bat::Deployment
          if deployments.include?(deployment)
            puts 'deployment already deployed'
          else
            puts 'deployment not deployed'
            deployment.generate_deployment_manifest(@spec)
            bosh_safe("deployment #{deployment.to_path}").should succeed
            bosh_safe('deploy').should succeed
          end
        when :no_tasks_processing
          if tasks_processing?
            raise "director `#{bosh_director}' is currently processing tasks"
          end
        else
          raise "unknown requirement: #{what}"
      end
    end

    def cleanup(what)
      case what
        when Bat::Stemcell
          bosh_safe("delete stemcell #{what.name} #{what.version}").should succeed
        when Bat::Release
          bosh_safe("delete release #{what.name}").should succeed
        when Bat::Deployment
          bosh_safe("delete deployment #{what.name}").should succeed
          what.delete
        else
          raise "unknown cleanup: #{what}"
      end
    end

    def reload_deployment_spec
      @spec = nil
      load_deployment_spec
    end

    def load_deployment_spec
      @spec ||= Psych.load_file(BoshHelper.read_environment('BAT_DEPLOYMENT_SPEC'))
      # Always set the batlight.missing to something, or deployments will fail.
      # It is used for negative testing.
      @spec['properties']['batlight'] ||= {}
      @spec['properties']['batlight']['missing'] = 'nope'
      @spec['properties']['dns_nameserver'] = bosh_dns_host if bosh_dns_host
    end

    # if with_deployment() is called without a block, it is up to the caller to
    # remove the generated deployment file
    # @return [Bat::Deployment]
    def with_deployment(spec = {}, &block)
      deployed = false # move into Deployment ?
      deployment = Bat::Deployment.new(@spec.merge(spec))

      if !block_given?
        return deployment
      elsif block.arity == 0
        bosh("deployment #{deployment.to_path}").should succeed
        bosh('deploy').should succeed
        deployed = true
        yield
      elsif block.arity == 1
        yield deployment
      elsif block.arity == 2
        bosh("deployment #{deployment.to_path}").should succeed
        result = bosh('deploy')
        result.should succeed
        deployed = true
        yield deployment, result
      else
        raise "unknown arity: #{block.arity}"
      end
    ensure
      if block_given?
        deployment.delete if deployment
        if deployed
          bosh("delete deployment #{deployment.name}").should succeed
        end
      end
    end

    def with_tmpdir
      dir = nil
      back = Dir.pwd
      Dir.mktmpdir do |tmpdir|
        dir = tmpdir
        Dir.chdir(dir)
        yield dir
      end
    ensure
      Dir.chdir(back)
      FileUtils.rm_rf(dir) if dir
    end

    def use_job(job)
      @spec['properties']['job'] = job
    end

    def use_templates(templates)
      @spec['properties']['template'] = templates.map { |item| "\n      - #{item}" }.join
    end

    def use_job_instances(count)
      @spec['properties']['instances'] = count
    end

    def use_deployment_name(name)
      @spec['properties']['name'] = name
    end

    def deployment_name
      @spec.fetch('properties', {}).fetch('name', 'bat')
    end

    def use_static_ip
      @spec['properties']['use_static_ip'] = true
    end

    def no_static_ip
      @spec['properties']['use_static_ip'] = false
    end

    def static_ip
      @spec['properties']['static_ip']
    end

    def use_persistent_disk(size)
      @spec['properties']['persistent_disk'] = size
    end

    def use_canaries(count)
      @spec['properties']['canaries'] = count
    end

    def use_pool_size(size)
      @spec['properties']['pool_size'] = size
    end

    def use_password(passwd)
      @spec['properties']['password'] = passwd
    end

    def use_failing_job
      @spec['properties']['batlight']['fail'] = 'control'
    end

    def get_task_id(output, state = 'done')
      match = output.match(/Task (\d+) #{state}/)
      match.should_not be_nil
      match[1]
    end

    def events(task_id)
      result = bosh("task #{task_id} --raw")
      result.should succeed_with /Task \d+ \w+/

      event_list = []
      result.output.split("\n").each do |line|
        event = parse(line)
        event_list << event if event
      end
      event_list
    end

    def start_and_finish_times_for_job_updates(task_id)
      jobs = {}
      events(task_id).select do |e|
        e['stage'] == 'Updating job' && %w(started finished).include?(e['state'])
      end.each do |e|
        jobs[e['task']] ||= {}
        jobs[e['task']][e['state']] = e['time']
      end
      jobs
    end

    private

    def spec
      @spec ||= {}
    end

    def parse(line)
      JSON.parse(line)
    rescue JSON::ParserError => e
      puts "Failed to parse '#{line}': #{e}"
    end
  end
end
