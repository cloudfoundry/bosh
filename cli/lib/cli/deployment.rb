module Bosh
  module Cli

    class Deployment

      attr_reader :work_dir, :filename

      def self.all(work_dir)
        Dir[work_dir + '/deployments/*.yml'].map do |f|
          new(work_dir, File.basename(f, ".yml"))
        end
      end

      def initialize(work_dir, filename)
        @work_dir = work_dir
        @filename = filename
      end

      def valid?
        !(name.nil? || version.nil?)
      end

      def perform(api_client)
        return :invalid unless valid?
        api_client.upload_and_track("/deployments", "text/yaml", self.path)
      end
      
      def path
        File.expand_path(work_dir + "/deployments/#{self.filename}.yml")
      end

      def manifest
        @manifest ||= YAML.load_file(self.path)
      end
      
      def manifest_exists?
        File.exists?(self.path)
      end

      [ :target, :name, :version ].each do |property|
        define_method(property) do
          manifest[property.to_s]
        end
      end

    end
    
  end
end
