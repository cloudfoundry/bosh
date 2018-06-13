Sequel.migration do
  up do
    if %i[mysql mysql2].include? adapter_scheme
      set_column_type :link_provider_intents, :metadata, 'longtext'
      set_column_type :link_consumer_intents, :metadata, 'longtext'
    end
  end
end
