Sequel.migration do
  up do
    if [:mysql2, :mysql].include?(self.adapter_scheme)
      self.tables.each do |table|
        if self[table].empty?
          self.run(%Q|ALTER TABLE #{table.to_s} CONVERT TO CHARACTER SET "utf8mb4";|)
        end
      end

      self.run(%Q|ALTER DATABASE DEFAULT CHARACTER SET "utf8mb4";|)
    end
  end
end
