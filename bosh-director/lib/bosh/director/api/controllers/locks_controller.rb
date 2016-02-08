module Bosh::Director
  module Api::Controllers
    class LocksController < BaseController
      get '/', scope: :read do
        redis = Config.redis

        locks = []
        lock_keys = redis.keys('lock:*')
        # Deliberatelly not using redis futures here as we expect that the number of lock keys will be very small
        lock_keys.each do |lock_key|
          lock_value = redis.get(lock_key)
          unless lock_value.nil?
            lock_type     = lock_key.split(':')[1]
            lock_resource = lock_key.split(':')[2..-1]
            lock_timeout  = lock_value.split(':')[0]
            locks << { type: lock_type, resource: lock_resource, timeout: lock_timeout }
          end
        end

        content_type(:json)
        json_encode(locks)
      end
    end
  end
end
