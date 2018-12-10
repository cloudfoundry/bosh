module Bosh::Director
  module Api
    class DirectorVMInfo
      def self.get_disks_info(df_input)
        # when BPM, this is the mapping:
        #                      Real                    BPM
        # system          /                       /etc or /bin or /usr
        # persistent      /var/vcap/store         /var/vcap/store/director
        # ephemeral       /var/vcap/data          /

        disks_info = []

        lines = df_input.split("\n")

        lines.select! { |l| %r{/$} =~ l || %r{/var/vcap/store/director$} =~ l }

        lines.compact.each do |line|
          stats = line.split
          disk = {}
          disk['size'] = stats[1]
          disk['available'] = stats[3]
          disk['used'] = stats[4]

          case stats.last
          when %r{/$}
            disk['name'] = 'ephemeral'
          when %r{/var/vcap/store/director$}
            disk['name'] = 'persistent'
          end
          disks_info << disk
        end
        disks_info
      end
    end
  end
end
