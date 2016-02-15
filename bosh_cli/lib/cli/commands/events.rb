module Bosh::Cli::Command
  class Events < Base
    usage 'events'
    desc 'Show all deployment events'

    def list
      auth_required
      show_events
    end

    private
    def show_events
      events = director.list_events
      if events.empty?
        nl
        say('No events')
        nl
        return
      end

      events_table = table do |t|
        headings   = ["#", 'Name', 'Action', 'State', 'Result', 'Task', 'Timestamp']
        t.headings = headings

        events.each do |event|
          row = []
          row << event['id']
          row << "'#{event['target_name']}' #{event['target_type']}"
          row << event['event_action']
          row << event['event_state']
          row << event['event_result'].to_s.truncate(80)
          row << event['task_id']
          row << Time.at(event['timestamp']).utc
          t << row
        end
      end

      nl
      say(events_table)
      nl
    end
  end
end
