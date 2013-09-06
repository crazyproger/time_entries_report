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

      @project = Project.find(params[:id]) if params[:id]
      @query = TimeEntryQuery.build_from_params(params, :project => @project, :name => '_')

      sort_init(@query.sort_criteria.empty? ? [['spent_on', 'desc']] : @query.sort_criteria)
      sort_update(@query.sortable_columns)
      scope = time_entry_scope(:order => sort_clause)

      respond_to do |format|
        format.html {
          # Paginate results
          @entry_count = scope.count
          @entry_pages = Redmine::Pagination::Paginator.new @entry_count, per_page_option, params['page']
          @entries = scope.all(
              :include => [:project, :activity, :user, {:issue => :tracker}],
              :limit  =>  @entry_pages.per_page,
              :offset =>  @entry_pages.offset
          )
          @total_hours = scope.sum(:hours).to_f

          render :layout => !request.xhr?
        }
        format.api  {
          @entry_count = scope.count
          @offset, @limit = api_offset_and_limit
          @entries = scope.all(
              :include => [:project, :activity, :user, {:issue => :tracker}],
              :limit  => @limit,
              :offset => @offset
          )
        }
        format.atom {
          entries = scope.reorder("#{TimeEntry.table_name}.created_on DESC").all(
              :include => [:project, :activity, :user, {:issue => :tracker}],
              :limit => Setting.feeds_limit.to_i
          )
          render_feed(entries, :title => l(:label_spent_time))
        }
        format.csv {
          # Export all entries
          @entries = scope.all(
              :include => [:project, :activity, :user, {:issue => [:tracker, :assigned_to, :priority]}]
          )
          send_data(query_to_csv(@entries, @query, params), :type => 'text/csv; header=present', :filename => 'timelog.csv')
        }
      end
    end
  end
end