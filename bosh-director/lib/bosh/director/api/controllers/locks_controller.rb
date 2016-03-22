module Bosh::Director
  module Api::Controllers
    class LocksController < BaseController
      get '/', scope: :read do
        locks = []
        lock_records = Models::Lock.dataset.all
        lock_records.each do |lock_record|
          lock_type     = lock_record.name.split(':')[1]
          lock_resource = lock_record.name.split(':')[2..-1]
          lock_timeout  = lock_record.expired_at.strftime('%s.%6N')
          locks << { type: lock_type, resource: lock_resource, timeout: lock_timeout }
        end

        content_type(:json)
        json_encode(locks)
      end
    end
  end
end
