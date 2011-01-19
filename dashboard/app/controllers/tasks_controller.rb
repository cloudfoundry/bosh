class TasksController < ApplicationController
  before_filter :director_credentials_required

  def show
    task_id = params[:id]
    offset  = [ params[:offset].to_i, 0].max

    task_output, new_offset = director.get_task_output(task_id, offset)

    @lines = task_output.split(/\r?\n/)
    @state = director.get_task_state(task_id)

    respond_to do |format|
      format.json do
        render :json => {
          :html       => render_to_string(:partial => "tasks/output"),
          :new_offset => new_offset,
          :state      => @state
        }
      end
    end
  end

  def running
    get_tasks(:running)
  end

  def recent
    get_tasks(:recent)
  end

  protected

  def get_tasks(kind)

    @tasks = \
    case kind
    when :running
      DirectorTask.running(director)
    when :recent
      DirectorTask.recent(director)      
    end
    
    respond_to do |format|
      format.json do
        render :json => { :html => render_to_string(:partial => "tasks/list") }
      end
    end
  rescue Director::DirectorError => e
    respond_to do |format|
      format.json do
        render :json => { :error => e.message }
      end
    end    
  end
  
end
