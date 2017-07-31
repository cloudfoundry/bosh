module Bosh::Director
  class LocalDnsEncoder
    def initialize
      @azmutex = Mutex.new
      @azcache = {}
    end

    def encode_az(name)
      @azmutex.synchronize do
        unless @azcache.has_key?(name)
          begin
            v = Models::LocalDnsEncodedAz.create(name: name)
          rescue Sequel::UniqueConstraintViolation
            v = Models::LocalDnsEncodedAz.where(name: name).first
          end

          @azcache[name] = v.id
        end

        @azcache[name]
      end
    end
  end
end
