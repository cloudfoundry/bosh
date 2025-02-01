module IntegrationSupport
  class TmuxCommandBuilder
    def initialize(window_name)
      @window_name = window_name
      @created = false
    end

    def array_for(command)
      if @created
        split_tmux_window(command)
      else
        create_tmux_window(command)
      end
    end

    def array_for_kill
      @created = false
      %W[tmux kill-window -t #{@window_name}]
    end

    def array_for_post_start
      %W[tmux select-layout -E -t #{@window_name}]
    end

    private

    def create_tmux_window(command)
      @created = true
      %W[tmux new-window -n #{@window_name} -d #{command}]
    end

    def split_tmux_window(command)
      %W[tmux split-window -h -t #{@window_name} -d #{command}]
    end
  end
end
