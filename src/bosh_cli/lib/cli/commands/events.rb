module Bosh::Cli::Command
  class Events < Base
    usage 'events'
    desc 'Show all deployment events'
    option '--before-id id', Integer, 'Show all events with id less or equal to given id'
    option '--before timestamp', String, 'Show all events by the given timestamp (ex: 2016-05-08 17:26:32)'
    option '--after timestamp', String, 'Show all events after the given timestamp (ex: 2016-05-08 17:26:32)'
    option '--deployment name', String, 'Filter all events by the Deployment Name'
    option '--task id', String, 'Filter all events by the task id'
    option '--instance job_name/id', String, 'Filter all events by the instance job_name/id'

    def list
      auth_required
      show_events
    end

    private
    def show_events
      events = director.list_events(options)
      if events.empty?
        nl
        say('No events')
        nl
        return
      end

      events_table = table do |t|
        headings   = ['ID', 'Time', 'User', 'Action', 'Object type', 'Object ID', 'Task', 'Dep', 'Inst', 'Context']
        t.headings = headings

        events.each do |event|
          row = []
          id  = event['id']
          id  = "#{id} <- #{event['parent_id']}" if event['parent_id']
          row << id
          row << Time.at(event['timestamp']).utc.strftime('%a %b %d %H:%M:%S %Z %Y')
          row << event['user']
          row << event['action']
          row << event['object_type']
          row << event.fetch('object_name', '-')
          row << event.fetch('task', '-')
          row << event.fetch('deployment', '-')
          row << event.fetch('instance', '-')
          if !event.key?('context') || event['context'] == nil
            event['context'] = {}
          end
          context = event['error'] ? {'error' => event['error'].to_s.truncate(80)}.merge(event['context']) : event['context']
          context = context.empty? ? '-' : context.map { |k, v| "#{k}: #{v}" }.join(",\n")
          row << context
          t << row
        end
      end

      nl
      say(events_table)
      nl
    end
  end
end
