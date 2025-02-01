module IntegrationSupport
  class ShellCommandBuilder
    def initialize(_unused)

    end

    def array_for(command)
      command.split(' ')
    end

    def array_for_kill
      %w[true]
    end

    def array_for_post_start
      %w[true]
    end
  end
end
