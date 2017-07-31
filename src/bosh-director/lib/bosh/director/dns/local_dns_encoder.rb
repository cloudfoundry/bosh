module Bosh::Director
  class LocalDnsEncoder
    def initialize
      @azmutex = Mutex.new
      @azcache = {}
    end

    def encode_az(name)
      @azmutex.synchronize do
        unless @azcache.has_key?(name)
          vs = Models::LocalDnsEncodedAz.where(name: name)

          if vs.nil? || vs.first.nil?
            v = Models::LocalDnsEncodedAz.create(name: name)
          else
            v = vs.first
          end

          @azcache[name] = v.id
        end

        @azcache[name]
      end
    end
  end
end
