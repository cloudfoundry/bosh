require 'rbcurse'

module VCAP
  module Micro
    class Console
      include RubyCurses
      include RubyCurses::Utils

      def self.run
        begin
          VER::start_ncurses
          self.new.console
        ensure
          VER::stop_ncurses
        end
      end

      def initialize
        # So much hate - so little time
        $log = Logger.new('/dev/null')

        @layout = { :height => 0, :width => 0, :top => 0, :left => 0 }
        @window = VER::Window.new(@layout)
      end

      def console

        @form = Form.new(@window)
        label_text = "VMware VCAP Micro Cloud Foundry"
        label = RubyCurses::Label.new(@form, {'text' => label_text, "row" => Ncurses.LINES-3, "col" => 2, "color" => "yellow", "height"=>2})

        @form.repaint
        @window.refresh

        while((ch = @window.getchar()) != ?\C-q.getbyte(0) )
          @form.repaint
          @window.wrefresh
          sleep 0.1
        end
      end
    end
  end
end

if $0 == __FILE__
  VCAP::Micro::Console.run
end

