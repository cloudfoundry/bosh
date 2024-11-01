module IntegrationSupport
  class ShellRunner
    def run(command)
      command.split(' ')
    end

    def kill
      %w[true]
    end

    def after_start
      %w[true]
    end
  end
end
