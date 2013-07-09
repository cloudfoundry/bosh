module Bosh
  module Dev
    class VersionFile < Struct.new(:version_number)
      def write
        file_contents = File.read("BOSH_VERSION")
        file_contents.gsub!(/^([\d\.]+)\.pre\.\d+$/, "\\1.pre.#{version_number}")
        File.open("BOSH_VERSION", 'w') { |f| f.write file_contents }
      end
    end
  end
end
