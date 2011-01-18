module ApplicationHelper

  def page_title
    default_title = "Bosh Dashboard"
    @page_title.present? ? "%s - %s" % [ h(@page_title), default_title ] : default_title
  end
  
end
