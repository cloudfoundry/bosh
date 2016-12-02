module Bosh
  module Cli
    class FileWithProgressBar < ::File

      def progress_bar
        return @progress_bar if @progress_bar
        out = Bosh::Cli::Config.output || StringIO.new
        @progress_bar = ProgressBar.new(file_name, size, out)
        @progress_bar.file_transfer_mode
        @progress_bar
      end

      def file_name
        File.basename(self.path)
      end

      def stop_progress_bar
        progress_bar.halt unless progress_bar.finished?
      end

      def size
        @size || File.size(self.path)
      end

      def size=(size)
        @size=size
      end

      def read(*args)
        result = super(*args)

        if result && result.size > 0
          progress_bar.inc(result.size)
        else
          progress_bar.set(size)
          progress_bar.finish
        end

        result
      end

      def write(*args)
        count = super(*args)
        if count
          progress_bar.inc(count)
        else
          progress_bar.set(size)
          progress_bar.finish
        end
        count
      end
    end
  end
end
