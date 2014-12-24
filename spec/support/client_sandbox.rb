class ClientSandbox
  class << self
    def base_dir
      File.join(BASE_TMP_DIR, 'client-sandbox')
    end

    def test_release_dir
      File.join(base_dir, 'test_release')
    end

    def bosh_work_dir
      File.join(base_dir, 'bosh_work_dir')
    end

    def bosh_config
      File.join(base_dir, 'bosh_config.yml')
    end
  end
end
