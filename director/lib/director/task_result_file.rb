module Bosh::Director

  class TaskResultFile
    def initialize(file_name)
      @file = File.open(file_name, "w")
      @lock = Mutex.new
    end

    def write(result)
      @lock.synchronize do
        @file.write(result)
        @file.flush
      end
    end
  end
end

