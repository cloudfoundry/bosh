require 'cli/download_with_progress'

module Bosh::Cli
  class PublicStemcellPresenter
    def initialize(ui, public_stemcells)
      @ui = ui
      @public_stemcells = public_stemcells
    end

    def list(options)
      full = !!options[:full]
      stemcells_table = @ui.table do |t|
        t.headings = full ? %w(Name Url) : %w(Name)

        stemcell_for(options).each do |stemcell|
          t << (full ? [stemcell.name, stemcell.url] : [stemcell.name])
        end
      end

      @ui.say(stemcells_table.render)
      @ui.say('To download use `bosh download public stemcell <stemcell_name>`. For full url use --full.')
    end

    def download(stemcell_name)
      unless @public_stemcells.has_stemcell?(stemcell_name)
        @ui.err("'#{stemcell_name}' not found.")
      end

      if File.exists?(stemcell_name) && !@ui.confirmed?("Overwrite existing file '#{stemcell_name}'?")
        @ui.err("File '#{stemcell_name}' already exists")
      end

      stemcell = @public_stemcells.find(stemcell_name)
      download_with_progress = DownloadWithProgress.new(stemcell.url, stemcell.size)
      download_with_progress.perform

      @ui.say('Download complete'.make_green)
    end

    private

    def stemcell_for(options)
      options[:all] ? @public_stemcells.all : @public_stemcells.recent
    end
  end
end
