rake_paths = File.expand_path('tasks/**/*.rake', File.dirname(__FILE__))
Dir.glob(rake_paths).each { |r| import r }
