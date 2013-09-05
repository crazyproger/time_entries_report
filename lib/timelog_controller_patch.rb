require_dependency 'timelog_controller'

module TimelogControllerPatch
  def self.included(base)
    base.send(:include, InstanceMethods)
    base.send(:before_filter, :authorize, :except => [:new, :index, :report, :detailed])
    base.send(:before_filter, :find_optional_project, :only => [:index, :report, :detailed])
    base.send(:before_filter, :authorize_global, :only => [:new, :index, :report, :detailed])
  end

  module InstanceMethods
    def detailed
      respond_to do |format|
        format.html {render :layout => !request.xhr? }
      end
    end
  end
end