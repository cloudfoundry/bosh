# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent
  class Platform::Linux::Service
    attr_reader :name

    def initialize(name)
      @name = name
    end

    def start_and_wait(timeout=3)
      start
      return if timeout == 0
      timeout.times do
        return true if running?

        Kernel::sleep 1
      end

      raise "Timeout to start service #{name}"
    end

    def stop_and_wait(timeout=3)
      stop
      return if timeout == 0
      timeout.times do
        return true unless running?

        Kernel::sleep 1
      end

      raise "Timeout to stop service #{name}"
    end

    def start
      Bosh::Exec.sh "service #{name} start"
    end

    def stop
      Bosh::Exec.sh "service #{name} stop"
    end

    def status
      Bosh::Exec.sh "service #{name} status"
    end

    def running?
      status.output =~ /running/ ? true : false
    end

    def exists?
      File.exists? "/etc/init.d/#{name}"
    end
  end
end
