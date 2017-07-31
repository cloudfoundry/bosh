Sequel.migration do
  up do
    create_table :availability_zones do
      primary_key :id
      String :name, text: true, unique: true, null: false
    end

    self[:instances].each do |instance|
      if instance[:availability_zone] !=nil && self[:availability_zones].where(name: instance[:availability_zone]).empty? then
        self[:availability_zones].insert(name: instance[:availability_zone])
      end
    end
  end
end
