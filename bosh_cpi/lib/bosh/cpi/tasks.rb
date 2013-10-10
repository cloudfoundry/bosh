Dir.glob(File.expand_path('tasks/**/*.rake', File.dirname(__FILE__))).each { |r| import r }
