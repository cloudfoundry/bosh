module Bosh::Cli::Command
  class Echo < Base

    command :banner do
      usage "banner <string>"
      desc "Print a large banner"
      route :echo, :banner
    end

    command :say do
      usage "say <string> <color>"
      desc "Say something with color"
      option "--color <color>", "color"
      route :echo, :say_color
    end

    def parse_options(args)
      options = {}
      ["color"].each do |option|
        pos = args.index("--#{option}")
        if pos
          options[option] = args[pos + 1]
          args.delete_at(pos + 1)
          args.delete_at(pos)
        end
      end
      options
    end

    def banner(string)
      system "banner #{string}"
    end

    def say_color(*args)
      string = args.shift
      options = parse_options(args)
      if color = options["color"]
        string = string.send(:make_color, color.to_sym)
      end
      say(string)
    end
  end
end
