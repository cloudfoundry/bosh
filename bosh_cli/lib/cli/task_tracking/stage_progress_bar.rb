module Bosh::Cli::TaskTracking
  class StageProgressBar
    attr_accessor :total
    attr_accessor :title
    attr_accessor :current
    attr_accessor :label
    attr_accessor :bar_visible
    attr_accessor :finished_steps
    attr_accessor :terminal_width

    def initialize(output)
      @output = output
      @current = 0
      @total = 100
      @bar_visible = true
      @finished_steps = 0
      @filler = 'o'
      @terminal_width = calculate_terminal_width
      @bar_width = (0.24 * @terminal_width).to_i # characters
    end

    def refresh
      clear_line
      bar_repr = @bar_visible ? bar : ''
      title_width = (0.35 * @terminal_width).to_i
      title = @title.truncate(title_width).ljust(title_width)
      @output.print "#{title} #{bar_repr} #{@finished_steps}/#{@total}"
      @output.print " #{@label}" if @label
    end

    def bar
      n_fillers = @total == 0 ? 0 : [(@bar_width *
        (@current.to_f / @total.to_f)).floor, 0].max

      fillers = "#{@filler}" * n_fillers
      spaces = ' ' * [(@bar_width - n_fillers), 0].max
      "|#{fillers}#{spaces}|"
    end

    def clear_line
      @output.print("\r")
      @output.print(' ' * @terminal_width)
      @output.print("\r")
    end

    def calculate_terminal_width
      if ENV['COLUMNS'].to_s =~ /^\d+$/
        ENV['COLUMNS'].to_i
      elsif !ENV['TERM'].blank?
        width = `tput cols`
        $?.exitstatus == 0 ? [width.to_i, 100].min : 80
      else
        80
      end
    rescue
      80
    end
  end
end
