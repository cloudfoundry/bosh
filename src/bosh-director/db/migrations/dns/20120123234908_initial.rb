Sequel.migration do
  change do
    create_table :domains do
      primary_key :id
      String :name, :size => 255, :null => false, :unique => true
      String :master, :size => 128, :null => true, :default => nil
      Integer :last_check, :null => true, :default => nil
      String :type, :size => 6, :null => false
      Integer :notified_serial, :null => true, :default => nil
      String :account, :size=> 40, :null => true, :default => nil
    end

    create_table :records do
      primary_key :id
      String :name, :size => 255, :null => true, :default => nil, :index => true
      String :type, :size => 10, :null => true, :default => nil
      String :content, :size => 4098, :null => true, :default => nil
      Integer :ttl, :null => true, :default => nil
      Integer :prio, :null => true, :default => nil
      Integer :change_date, :null => true, :default => nil
      foreign_key :domain_id, :domains, :on_delete => :cascade, :null => true, :default => nil, :index => true
      index [:name, :type]
    end
  end
end
