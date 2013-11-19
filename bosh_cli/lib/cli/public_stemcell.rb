module Bosh::Cli
  class PublicStemcell
    attr_reader :size

    def initialize(key, size)
      @key = key
      @size = size
    end

    def name
      File.basename(@key)
    end

    def version
      version_digits = @key.gsub(/[^\d]/, '')
      version_digits.to_i
    end

    def variety
      name.gsub(version.to_s, '')
    end

    def url
      "#{PublicStemcells::PUBLIC_STEMCELLS_BASE_URL}/#{@key}"
    end

    def legacy?
      @key.include?('legacy')
    end
  end
end
