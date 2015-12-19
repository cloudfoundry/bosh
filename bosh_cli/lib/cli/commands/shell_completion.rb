# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli::Command
  class ShellCompletion < Base
    usage "shell-completion"
    desc "Generate script for shells supporting command completion."
    def exec
      say "#"
      say "# Install this script in your shell to auto-complete your BOSH commands."
      say "# "
      say "# bash ~4.0: source <( bosh shell-completion )"
      say "# bash ~3.0: bosh shell-completion | source /dev/stdin"
      say "#"
      say ""

      wordtree = build_wordtree

      print_header
      print_wordtree(1, wordtree)
      print_footer
    end

    private

    def build_wordtree()
      wordtree = {}

      Bosh::Cli::Config.commands.values.each do | command |
        command.usage # "create release"

        link = wordtree

        command.keywords.each do | cmd |
          unless link.has_key?(cmd)
            link[cmd] = {}
          end

          link = link[cmd]
        end

        link[''] = {}

        command.options.each do | option |
          link[option[0].split(/\s/)[0]] = {}
        end
      end

      wordtree
    end


    def print_header()
      say <<EOF
_BoshShellCompletion()
{
  local cur opts

  COMPREPLY=()
  cur=${COMP_WORDS[COMP_CWORD]}

EOF
    end

    def print_wordtree(level, wordtree)
      indent = '  ' + ' ' * ((level - 1) * 2)

      if 1 == wordtree.keys.length && wordtree.has_key?('')
        return
      end

      say indent + "case \"${COMP_WORDS[#{level}]}\" in"

      wordtree.each do | word, children |
        next if children.empty?

        say indent + "  #{word})"
        print_wordtree(level + 1, children)
        say indent + "  ;;"
      end

      say indent + "  *)"
      say indent + "    opts=\" #{wordtree.keys.join(' ').strip} \""
      say indent + "  ;;"

      say indent + "esac"
    end

    def print_footer()
      say <<EOF

  for COMP_WORD in "${COMP_WORDS[@]}" ; do
    opts=${opts/ $COMP_WORD / }
  done

  COMPREPLY=( $( compgen -W "$opts" -- $cur ) )

  return 0
}

complete -F _BoshShellCompletion bo bosh -o filenames
EOF
    end
  end
end
