module Bosh::Cli
  class PublicStemcell
    attr_reader :size

    def initialize(key, size)
      @key = key
      @size = size

      @parsed_version = key.scan(/[\d]*_?[\d]+/).first
    end

    def name
      File.basename(@key)
    end

    def version
      @parsed_version.gsub('_', '.').to_f
    end

    def variety
      name.gsub(/(.tgz)|(bosh-stemcell-)|(#{@parsed_version})/, '').split('-').reject { |c| c.empty? }.join('-')
    end

    def url
      "#{PublicStemcells::PUBLIC_STEMCELLS_BASE_URL}/#{@key}"
    end

    def legacy?
      @key.include?('legacy')
    end

  end
end
