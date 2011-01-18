class StemcellsController < ApplicationController
  before_filter :director_credentials_required

  def index
    @stemcells = Stemcell.all(director)
    respond_to do |format|
      format.json do
        render :json => { :html => render_to_string(:partial => "stemcells/list") }
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
