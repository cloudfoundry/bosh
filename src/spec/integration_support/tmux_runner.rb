module IntegrationSupport
  class TmuxRunner
    def initialize(window_name)
      @window_name = window_name
      @created = false
    end

    def run(command)
      if @created
        split(command)
      else
        create(command)
      end
    end

    def kill
      @created = false
      %W[tmux kill-window -t #{@window_name}]
    end

    def after_start
      %W[tmux select-layout -E -t #{@window_name}]
    end

    private

    def create(command)
      @created = true
      %W[tmux new-window -n #{@window_name} -d #{command}]
    end

    def split(command)
      # "tmux select-layout -E -t #{@window_name}"
      %W[tmux split-window -h -t #{@window_name} -d #{command}]
    end
  end
end
