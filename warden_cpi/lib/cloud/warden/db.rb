
module Bosh::WardenCloud

  class DB

    def initialize(options)
      db_type = options["type"]
      db_file = options["path"]

      if db_type != "sqlite"
        raise Bosh::Clouds::NotSupported, "#{db_type} not supported"
      end

      FileUtils.mkdir_p(File.dirname(db_file))
      @db = Sequel.connect("#{db_type}://#{db_file}")

      # create tables if not exist
      @db.create_table? :disk do
        primary_key String :uuid
        Int :device_num
      end

      @db.create_table? :disk_mapping do
        primary_key String :disk_id
        String :container_id
        String :device_path
      end
    end

    def device_ocuppied?(device_num)
      items = @db[:disk]
      items.each do |item|
        return true if item[:device_num] == device_num
      end
      false
    end

    def save_disk(disk)
      items = @db[:disk]
      items.insert(:uuid => "#{disk.uuid}", :device_num => "#{device_num}")
    end
  end
end
