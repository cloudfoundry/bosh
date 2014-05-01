require 'tmpdir'
require 'logger'

module Bat
  module DeploymentHelper
    def deployment
      load_deployment_spec
      @deployment ||= Bat::Deployment.new(@spec)
    end

    def reload_deployment_spec
      @spec = nil
      load_deployment_spec
    end

    def load_deployment_spec
      @spec ||= Psych.load_file(@env.deployment_spec_path)
      # Always set the batlight.missing to something, or deployments will fail.
      # It is used for negative testing.
      @spec['properties']['batlight'] ||= {}
      @spec['properties']['batlight']['missing'] = 'nope'
      @spec['properties']['dns'] = [@env.dns_host]
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
        @bosh_runner.bosh("deployment #{deployment.to_path}").should succeed
        @bosh_runner.bosh('deploy').should succeed
        deployed = true
        yield
      elsif block.arity == 1
        yield deployment
      elsif block.arity == 2
        @bosh_runner.bosh("deployment #{deployment.to_path}").should succeed
        result = @bosh_runner.bosh('deploy')
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
          @bosh_runner.bosh("delete deployment #{deployment.name}").should succeed
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

    def use_additional_dns_server(dns_server)
      @spec['properties']['dns'] = [dns_server, @env.dns_host]
    end

    def deployment_name
      @spec.fetch('properties', {}).fetch('name', 'bat')
    end

    def use_vip
      @spec['properties']['use_vip'] = true
    end

    def no_vip
      @spec['properties']['use_vip'] = false
    end

    def public_ip
      # For AWS and OpenStack, the elastic IP is the public IP
      # For vSphere and vCloud, the static_ip is the public IP
      @spec['properties']['vip'] || @spec['properties']['deployment_static_ip']
    end

    def use_static_ip
      @spec['properties']['use_static_ip'] = true
      @spec['properties']['deployment_static_ip'] = static_ip
      @spec['properties']['mbus'] = mbus_url(static_ip)
    end

    def no_static_ip
      @spec['properties']['use_static_ip'] = false
    end

    def static_ip
      @spec['properties']['static_ip']
    end

    def use_second_static_ip
      @spec['properties']['use_static_ip'] = true
      @spec['properties']['deployment_static_ip'] = second_static_ip
      @spec['properties']['mbus'] = mbus_url(second_static_ip)
    end

    def second_static_ip
      @spec['properties']['second_static_ip']
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

    def dynamic_network?
      network_type == 'dynamic'
    end

    def network_type
      @spec['properties'].fetch('network', {}).fetch('type', nil)
    end

    def get_task_id(output, state = 'done')
      task_regex = /Task (\d+) #{state}/
      expect(output).to match(task_regex)
      match = output.match(task_regex)
      match[1]
    end

    def events(task_id)
      result = @bosh_runner.bosh("task #{task_id} --raw")
      result.should succeed_with /Task \d+ \w+/

      event_list = []
      result.output.split("\n").each do |line|
        event = parse_json_safely(line)
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

    def mbus_url(ip)
      "nats://nats:0b450ada9f830085e2cdeff6@#{ip}:4222"
    end

    def spec
      @spec ||= {}
    end

    def parse_json_safely(line)
      JSON.parse(line)
    rescue JSON::ParserError => e
      @logger.info("Failed to parse '#{line}': #{e.inspect}")
      nil
    end
  end
end
