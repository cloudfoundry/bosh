module Bosh
  module Cli
    class Terminal
      extend Forwardable

      def initialize(highline, sayer)
        @highline = highline
        @sayer = sayer
      end

      def ask(prompt)
        highline.ask(prompt).to_s # make sure we return a String not a HighLine::String
      end

      def ask_password(prompt)
        highline.ask(prompt) { |q| q.echo = false }.to_s
      end

      def say_green(message)
        sayer.say(message.make_green)
      end

      def say_red(message)
        sayer.say(message.make_red)
      end

      private
      attr_reader :highline, :sayer
    end
  end
end
