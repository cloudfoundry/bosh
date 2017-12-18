require 'delayed/backend/sequel'

module Bosh
  module Director
    module Models
      Delayed::Backend::Sequel::Job.class_eval do
        many_to_many :delayed_job_groups, class: 'Bosh::Director::Models::DelayedJobGroup'

        def self.all_blocked_jobs
          delayed_job_groups = db[:delayed_job_groups]
          delayed_job_groups_jobs = db[:delayed_job_groups_jobs]
          non_reservable_groups = delayed_job_groups.where do |group|
            job_ids_in_group = delayed_job_groups_jobs.where(delayed_job_group_id: group.group_id).select(:job_id)
            group.limit <= filter(failed_at: nil).exclude(locked_by: nil).where(id: job_ids_in_group).select { count.function.* }
          end

          delayed_job_groups_jobs.where(delayed_job_group_id: non_reservable_groups.select(:group_id)).select(:job_id)
        end

        module ReadyToRunExtension
          def ready_to_run(worker_name, max_run_time)
            super(worker_name, max_run_time).exclude(id: all_blocked_jobs)
          end
        end

        class << self
          prepend ReadyToRunExtension
        end
      end

      class DelayedJobGroup < Sequel::Model(Bosh::Director::Config.db)
        many_to_many :delayed_jobs, class: 'Delayed::Backend::Sequel::Job', right_key: :job_id

        def validate
          validates_presence [:config_content]
        end
      end
    end
  end
end
