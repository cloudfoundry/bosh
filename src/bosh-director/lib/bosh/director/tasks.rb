BOSH_DIRECTOR_LIB_ROOT = File.expand_path(File.dirname(__FILE__))

Dir.glob(File.join(BOSH_DIRECTOR_LIB_ROOT, 'tasks','**','*.rake')).each { |r| import r }
