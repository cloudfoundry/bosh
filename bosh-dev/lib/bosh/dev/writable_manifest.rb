require 'yaml'

module Bosh::Dev
  module WritableManifest
    def write
      File.open(filename, 'w+') do |f|
        f.write(to_h.to_yaml)
      end
    end
  end
end
