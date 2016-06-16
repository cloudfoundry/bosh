module Bosh::Cli
  class NonInteractiveProgressRenderer
    def initialize
      @mutex = Mutex.new
    end

    def start(path, label)
      render(path, label)
    end

    def progress(path, label, percent)
    end

    def error(path, message)
      render(path, message)
    end

    def finish(path, label)
      render(path, label)
    end

    private

    def render(path, label)
      @mutex.synchronize do
        truncated_path = path.truncate(40)
        say("#{truncated_path} #{label}")
        Bosh::Cli::Config.output.flush # Ruby 1.8 compatibility
      end
    end
  end
end
