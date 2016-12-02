Sequel.migration do
  change do
    unless [:sqlite].include?(adapter_scheme)
      set_column_type :events, :id, Bignum
      set_column_type :events, :parent_id, Bignum
    end
  end
end
