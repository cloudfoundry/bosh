# frozen_string_literal: true

# @AI-Generated
# Modified with AI assistance
# Description:
# 2026-05-19: Fix Sequel log_connection_yield race condition under YJIT - Cursor: Claude Sonnet 4.6

# TNZ-103317: Sequel::Database#log_connection_yield reassigns its `sql` parameter
# to prepend "(conn: N)" for logging. Under YJIT, blocks closed over the caller's
# `sql` variable can incorrectly resolve to this modified value, sending the
# prefixed string to PostgreSQL and causing a PG::SyntaxError.
#
# Fix: rename the local variable used for logging so the block closure can never
# capture it instead of the caller's original SQL string.
module Bosh
  module Director
    module SequelLoggingFix
      def log_connection_yield(sql, conn, args = nil)
        return yield if skip_logging?

        log_sql = "#{connection_info(conn) if conn && log_connection_info}#{sql}#{"; #{args.inspect}" if args}"
        timer = Sequel.start_timer

        begin
          yield
        rescue => e
          log_exception(e, log_sql)
          raise
        ensure
          log_duration(Sequel.elapsed_seconds_since(timer), log_sql) unless e
        end
      end
    end
  end
end

Sequel::Database.prepend(Bosh::Director::SequelLoggingFix)
