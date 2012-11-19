
module Bosh::WardenCloud

  class DB

    def initialize(type, path)
      if type != "sqlite"
        raise Bosh::Clouds::NotSupported, "#{type} not supported"
      end

      FileUtils.mkdir_p(File.dirname(path))
      @db = Sequel.connect("#{type}://#{path}")

      # create tables if not exist
      @db.create_table? :disk do
        primary_key String :uuid
        Int :device_num
      end
    end

    def device_occupied?(device_num)
      @db[:disk][:device_num => device_num].nil?
    end

    def save_disk(disk)
      items = @db[:disk]
      items.insert(:uuid => "#{disk.uuid}", :device_num => "#{device_num}")
    end

    def find_disk(disk_id)
      data = @db[:disk][:uuid => disk_id]
      unless data
        raise Bosh::Clouds::DiskNotFound, "Disk #{disk_id} not exist"
      end
      Disk.new(disk_id, data[:device_num])
    end

    def delete_disk(disk)
      @db[:disk].where(:uuid => disk.uuid).delete
    end
  end
end
