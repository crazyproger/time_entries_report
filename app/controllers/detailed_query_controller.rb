class DetailedQueryController < ApplicationController
  unloadable

  before_filter :authorize_global, :only => [:detailed, :detailed_time_log]
  before_filter :find_optional_project, :only => [:detailed, :detailed_time_log]
  accept_rss_auth :detailed, :detailed_time_log
  accept_api_auth :detailed, :detailed_time_log

  rescue_from Query::StatementInvalid, :with => :query_statement_invalid

  helper :timelog
  helper :queries
  include QueriesHelper
  helper :issues
  helper :sort
  include SortHelper

  def detailed
    @total_hours=0
    @query = IssueByTimeEntryQuery.new(:name => "_")
    @query.project = @project
    @query.build_from_params(params)

    sort_init(@query.sort_criteria.empty? ? [['id', 'desc']] : @query.sort_criteria)
    sort_update(@query.sortable_columns)
    @query.sort_criteria = sort_criteria.to_a

    if @query.valid?
      case params[:format]
        when 'csv', 'pdf'
          @limit = Setting.issues_export_limit.to_i
        when 'atom'
          @limit = Setting.feeds_limit.to_i
        when 'xml', 'json'
          @offset, @limit = api_offset_and_limit
        else
          @limit = per_page_option
      end

      @issue_count = @query.entry_count
      @issue_pages = Paginator.new @issue_count, @limit, params['page']
      @offset ||= @issue_pages.offset
      query_params = {:include => [:assigned_to, :tracker, :priority, :category, :fixed_version],
              :order => sort_clause,
              :offset => @offset,
              :limit => @limit}
      @issues = @query.entries(query_params)
      @issue_count_by_group = @query.entry_count_by_group

      respond_to do |format|
        format.html {
          @total_hours = @query.entries_scope(query_params).sum("#{TimeEntry.table_name}.hours").to_f
          render :layout => !request.xhr? }
        format.api  {
          Issue.load_visible_relations(@issues) if include_in_api_response?('relations')
        }
        format.atom { render_feed(@issues, :title => "#{@project || Setting.app_title}: #{l(:label_issue_plural)}") }
        format.csv  { send_data(query_to_csv(@issues, @query, params), :type => 'text/csv; header=present', :filename => 'issues.csv') }
        format.pdf  { send_data(issues_to_pdf(@issues, @project, @query), :type => 'application/pdf', :filename => 'issues.pdf') }
      end
    else
      respond_to do |format|
        format.html { render(:layout => !request.xhr?) }
        format.any(:atom, :csv, :pdf) { render(:nothing => true) }
        format.api { render_validation_errors(@query) }
      end
    end
  end

  def detailed_time_log
    @query = TimeEntryExtendedQuery.build_from_params(params, :project => @project, :name => '_')

    sort_init(@query.sort_criteria.empty? ? [['spent_on', 'desc']] : @query.sort_criteria)
    sort_update(@query.sortable_columns)
    scope = time_entry_scope(:order => sort_clause)

    respond_to do |format|
      format.html {
        # Paginate results
        @entry_count = scope.count
        @entry_pages = Paginator.new @entry_count, per_page_option, params['page']
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
      format.csv {
        # Export all entries
        @entries = scope.all(
            :include => [:project, :activity, :user, {:issue => [:tracker, :assigned_to, :priority]}]
        )
        send_data(query_to_csv(@entries, @query, params), :type => 'text/csv; header=present', :filename => 'timelog.csv')
      }
    end
  end

  private
  def find_optional_project
    unless params[:project_id].blank?
      @project = Project.find(params[:project_id])
    end
  end

  # Returns the TimeEntry scope for index and report actions
  def time_entry_scope(options={})
    @query.results_scope(options)
  end
end
