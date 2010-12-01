module Bosh
  module Cli

    class Deployment

      attr_reader :work_dir, :name

      def self.all(work_dir)
        Dir[work_dir + '/deployments/*.yml'].map do |f|
          new(work_dir, File.basename(f, ".yml"))
        end
      end

      def initialize(work_dir, name)
        @work_dir = work_dir
        @name     = name
      end
      
      def path
        File.expand_path(work_dir + "/deployments/#{self.name}.yml")
      end

      def exists?
        File.exists?(self.path)
      end

      def target
        manifest["target"]
      end

      def manifest
        @manifest ||= YAML.load_file(self.path)
      end
      
    end
    
  end
end
