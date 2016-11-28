Sequel.extension :blank

Sequel::Model.plugin :validation_helpers
Sequel::Model.raise_on_typecast_failure = false

[:exact_length, :format, :includes, :integer, :length_range, :max_length,
 :min_length, :not_null, :numeric, :type, :presence, :unique].each do |validation|
  Sequel::Plugins::ValidationHelpers::DEFAULT_OPTIONS[validation][:message] = validation
end

Sequel::Plugins::ValidationHelpers::DEFAULT_OPTIONS[:max_length][:nil_message] = :max_length
