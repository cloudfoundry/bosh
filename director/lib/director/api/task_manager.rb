# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director::Api
  class TaskManager
    def task_to_json(task)
      {
        "id" => task.id,
        "state" => task.state,
        "description" => task.description,
        "timestamp" => task.timestamp.to_i,
        "result" => task.result,
        "user" => task.user ? task.user.username : "admin"
      }
    end
  end
end