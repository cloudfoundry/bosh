class TasksController < ApplicationController
  before_filter :director_credentials_required

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
