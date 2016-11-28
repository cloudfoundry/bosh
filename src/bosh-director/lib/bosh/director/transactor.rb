module Bosh::Director
  class Transactor
    def retryable_transaction(db, &block)
      Bosh::Common.retryable(tries: 3, on: [Sequel::DatabaseError], matching: /Mysql2::Error: Deadlock found when trying to get lock/) do |attempt, e|
        db.transaction(&block) || true
      end
    end
  end
end
