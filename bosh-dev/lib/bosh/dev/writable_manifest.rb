require 'yaml'

module Bosh::Dev
  module WritableManifest
    def write(file_name)
      File.open(file_name, 'w+') do |f|
        f.write(to_h.to_yaml)
      end
    end
  end
end
