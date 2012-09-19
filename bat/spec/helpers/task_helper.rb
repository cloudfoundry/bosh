# Copyright (c) 2012 VMware, Inc.

module TaskHelper

  def get_task_id(output)
    match = output.match(/Task (\d+) done/)
    match.should_not be_nil
    match[1]
  end

  def events(task_id)
    result = bosh("task #{task_id} --raw")
    result.should succeed_with /Task \d+ done/

    event_list = []
    result.output.split("\n").each do |line|
      event = parse(line)
      event_list << event if event
    end
    event_list
  end

  private

  def parse(line)
    JSON.parse(line)
  rescue JSON::ParserError
    # do nothing
  end

end
