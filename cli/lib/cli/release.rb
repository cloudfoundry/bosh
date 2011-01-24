module Bosh::Cli

  class Release

    def initialize(work_dir)
      @work_dir = work_dir
    end

    def dev_name
      read_name(dev_name_file)
    end

    def dev_version
      read_version(dev_version_file)
    end    

    def final_name
      read_name(final_name_file)
    end
    
    def final_version
      read_version(final_version_file)
    end

    def save_final_version(version)
      save_version(final_version_file, version)
    end

    def save_dev_version(version)
      save_version(dev_version_file, version)
    end    

    private

    def final_name_file
      File.join(@work_dir, "NAME")      
    end

    def dev_name_file
      File.join(@work_dir, "DEV_NAME")
    end

    def final_version_file
      File.join(@work_dir, "VERSION")
    end

    def dev_version_file
      File.join(@work_dir, "DEV_VERSION")      
    end

    def save_version(file, version)
      File.open(file, "w") do |f|
        f.write(version)
      end
    end
    
    def read_version(file)
      if File.exists?(file)
        File.read(file).to_i
      else
        nil
      end      
    end

    def read_name(file)
      if File.file?(file) && File.readable?(file)
        name = File.read(file).split("\n")[0]
        name.blank? ? nil : name
      else
        nil
      end
    end
    
  end

end
