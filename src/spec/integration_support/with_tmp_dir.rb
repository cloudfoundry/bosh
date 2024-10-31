module IntegrationSupport
  module WithTmpDir
    def with_tmp_dir_before_all
      before(:all) { @tmp_dir = Dir.mktmpdir }
      after(:all) { FileUtils.rm_rf(@tmp_dir) }
    end
  end
end

RSpec.configure do |config|
  config.extend(IntegrationSupport::WithTmpDir, with_tmp_dir: true)
end
