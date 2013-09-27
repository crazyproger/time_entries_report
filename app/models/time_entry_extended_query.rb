class TimeEntryExtendedQuery < TimeEntryQuery

  self.available_columns = [
      QueryColumn.new(:project, :sortable => "#{Project.table_name}.name", :groupable => true),
      QueryColumn.new(:user, :sortable => lambda {User.fields_for_order_statement}, :groupable => true),
      QueryColumn.new(:activity, :sortable => "#{TimeEntryActivity.table_name}.position", :groupable => true),
      QueryColumn.new(:issue, :sortable => "#{Issue.table_name}.id"),
      QueryColumn.new(:hours, :sortable => "#{TimeEntry.table_name}.hours"),
  ]

  def initialize(attributes=nil, *args)
    super attributes
    if self.filters.size<2
      self.filters = {
          :spent_on => {:operator => 'lm', :values => []},
      }
    end
  end

  def initialize_available_filters
    super
    if project
      versions = project.shared_versions.all
    else
      versions = Version.visible.find_all_by_sharing('system')
    end
    if versions.any?
      add_available_filter "fixed_version_id",
                           :type => :list_optional,
                           :values => versions.sort.collect { |s| ["#{s.project.name} - #{s.name}", s.id.to_s] }
    end
  end


  def build_from_params(params)
    super(params)
    parameters = params[:f]
    if parameters.nil? || (!parameters.include? 'spent_on')
      add_filter('spent_on', 'lm')
    end
    self
  end

  def available_columns
    return @available_columns if @available_columns
    @available_columns = self.class.available_columns.dup
    @available_columns += TimeEntryCustomField.all.map { |cf| QueryCustomFieldColumn.new(cf) }
    @available_columns += IssueCustomField.all.map { |cf| QueryAssociationCustomFieldColumn.new(:issue, cf) }
    @available_columns << QueryColumn.new(:issue_author)
    @available_columns << QueryColumn.new(:issue_assigned_to, :sortable => lambda { User.fields_for_order_statement('assigned_tos_issues') })
    @available_columns << QueryColumn.new(:issue_updated_on, :sortable => "#{Issue.table_name}.updated_on", :default_order => 'desc')
    @available_columns << QueryColumn.new(:issue_created_on, :sortable => "#{Issue.table_name}.created_on", :default_order => 'desc')
    @available_columns << QueryColumn.new(:issue_category, :sortable => 'issue_categories.name')
    @available_columns << QueryColumn.new(:issue_fixed_version, :sortable => "#{Version.table_name}.name")
    @available_columns << QueryColumn.new(:issue_due_date, :sortable => "#{Issue.table_name}.due_date")
    @available_columns << QueryColumn.new(:issue_estimated_hours, :sortable => "#{Issue.table_name}.estimated_hours")
    @available_columns << QueryColumn.new(:total_hours)
    @available_columns
  end

  def default_columns_names
    @default_columns_names ||= [:project, :user, :issue, :hours, :total_hours]
  end

  def results_scope(sort_clause)
    order_option = [group_by_sort_order, sort_clause].flatten.reject(&:blank?)
    _results_scope().order(order_option).joins(joins_for_order_statement(order_option.join(',')))
  end

  def _results_scope()
    TimeEntry.visible.
        where(statement).
        includes(:issue)
  end

  def count(sort_clause)
    scope = _results_scope
    scope.select('user_id, issue_id').uniq.count
  end

  def entries(options = {})
    default_includes = [:project, :activity, :user, {:issue => [:author, :tracker, :assigned_to, :category, :fixed_version]}]
    scope = results_scope(options.delete(:order)).includes(options.fetch(:include, default_includes))
    options.delete(:include)
    grouped = scope.group(:user_id, :issue_id)
    time_entries = grouped.clone.all(options)
    times = grouped.clone.sum(:hours)
    ids = time_entries.map {|te| te.issue_id}    #todo make set from array
    total_times = TimeEntry.group(:issue_id).where(issue_id:ids).sum(:hours)
    load_hours_to_entries(time_entries, times)
    load_total_hours_to_entries(time_entries, total_times)
    time_entries
  end

  def load_hours_to_entries(entries, times)
    if entries.any?
      entries.each do |entry|
        entry.hours=times[[entry.user_id, entry.issue_id]]
      end
    end
  end

  def load_total_hours_to_entries(entries, times)
    if entries.any?
      entries.each do |entry|
        entry.total_hours=times[entry.issue_id]
      end
    end
  end

  def sql_for_fixed_version_id_field(field, operator, value)
    '('+sql_for_field(field, operator, value, Issue.table_name, 'fixed_version_id')+')'
  end

end
