module Bosh::Cli::SourceControl
  class GitIgnore

    RELEASE_IGNORE_PATTERNS = [
      'config/dev.yml',
      'config/private.yml',
      'releases/*.tgz',
      'releases/**/*.tgz',
      'dev_releases',
      '.blobs',
      'blobs',
      '.dev_builds',
      '.idea',
      '.DS_Store',
      '.final_builds/jobs/**/*.tgz',
      '.final_builds/packages/**/*.tgz',
      '*.swp',
      '*~',
      '*#',
      '#*',
    ]

    def initialize(dir)
      @dir = dir
    end

    def update
      file_path = File.join(@dir, '.gitignore')

      found_patterns = []
      if File.exist?(file_path)
        File.open(file_path, 'r').each_line { |line| found_patterns << line.chomp }
      end

      File.open(file_path, 'a') do |f|
        RELEASE_IGNORE_PATTERNS.each do |pattern|
          f.print(pattern + "\n") unless found_patterns.include?(pattern)
        end
      end
    end
  end
end
