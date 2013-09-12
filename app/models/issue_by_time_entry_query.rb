class IssueByTimeEntryQuery < IssueQuery

  def initialize(attributes=nil, *args)
    super attributes
    if self.filters.size<2
      self.filters = {
          :time_spent_on => {:operator => 'lm', :values => []},
          :time_spent_user_id => {:operator => "*", :values => []}
      }
      #.merge(self.filters)
    end
  end

  def default_columns_names
    @default_columns_names ||= begin
      default_columns=[:status, :subject, :assigned_to, :updated_on, :spent_hours_filtered, :spent_hours]
      project.present? ? default_columns : [:project] | default_columns
    end
  end

  def initialize_available_filters
    super
    add_available_filter 'time_spent_on', :type => :date_past
    principals = []
    if project
      principals += project.principals.sort
    else
      if all_projects.any?
        # members of visible projects
        principals += Principal.member_of(all_projects)
      end
    end
    principals.uniq!
    principals.sort!
    users = principals.select { |p| p.is_a?(User) }

    users_values = []
    users_values << ["<< #{l(:label_me)} >>", "me"] if User.current.logged?
    users_values += users.collect { |s| [s.name, s.id.to_s] }
    add_available_filter('time_spent_user_id',
                         :type => :list_optional, :values => users_values
    ) unless users_values.empty?
  end

  def available_columns
    return @available_columns if @available_columns
    @available_columns = self.class.available_columns.dup
    @available_columns += (project ?
        project.all_issue_custom_fields :
        IssueCustomField.all
    ).collect { |cf| QueryCustomFieldColumn.new(cf) }

    if User.current.allowed_to?(:view_time_entries, project, :global => true)
      index = nil
      @available_columns.each_with_index { |column, i| index = i if column.name == :estimated_hours }
      index = (index ? index + 1 : -1)
      # insert the column after estimated_hours or at the end
      @available_columns.insert index, QueryColumn.new(:spent_hours,
                                                       :sortable => "COALESCE((SELECT SUM(hours) FROM #{TimeEntry.table_name} WHERE #{TimeEntry.table_name}.issue_id = #{Issue.table_name}.id), 0)",
                                                       :default_order => 'desc',
                                                       :caption => :label_spent_time
      )
      index = (index ? index + 1 : -1)
      @available_columns.insert index, QueryColumn.new(:spent_hours_filtered,
                                                       :caption => :label_spent_hours_filtered
      )
    end

    if User.current.allowed_to?(:set_issues_private, nil, :global => true) ||
        User.current.allowed_to?(:set_own_issues_private, nil, :global => true)
      @available_columns << QueryColumn.new(:is_private, :sortable => "#{Issue.table_name}.is_private")
    end

    disabled_fields = Tracker.disabled_core_fields(trackers).map { |field| field.sub(/_id$/, '') }
    @available_columns.reject! { |column|
      disabled_fields.include?(column.name.to_s)
    }

    @available_columns

  end

  def build_from_params(params)
    super
    parameters = params[:fields]
    parameters ||= params[:f]
    if parameters.nil? || (!parameters.include? 'time_spent_on')
        add_filter('time_spent_on', 'lm')
    end
  end


    # Returns the issues
  # Valid options are :order, :offset, :limit, :include, :conditions
  def entries(options={})
    order_option = [group_by_sort_order, options[:order]].flatten.reject(&:blank?)

    issues = Issue.visible.where(options[:conditions]).all(
        :include => ([:status, :project, :time_entries] + (options[:include] || [])).uniq,
        :conditions => statement,
        :order => order_option,
        :joins => query_joins(order_option.join(',')),
        :limit => options[:limit],
        :offset => options[:offset]
    #:group => "#{Issue.table_name}.id"
    )

    if has_column?(:spent_hours)
      Issue.load_visible_spent_hours(issues)
    end
    if has_column?(:spent_hours)
      if issues.any?
        issues.each do |issue|
          hours_filtered = issue.time_entries.to_a.map(&:hours).inject(0) { |x, y| x + y }
          issue.instance_variable_set '@spent_hours_filtered', (hours_filtered || 0)
        end
      end
    end
    if has_column?(:relations)
      Issue.load_visible_relations(issues)
    end
    issues
  rescue ::ActiveRecord::StatementInvalid => e
    raise StatementInvalid.new(e.message)
  end


  def entry_count
    Issue.visible.count(:include => [:status, :project, :time_entries], :conditions => statement)
  rescue ::ActiveRecord::StatementInvalid => e
    raise StatementInvalid.new(e.message)
  end

  def entry_count_by_group
    r = nil
    if grouped?
      begin
        # Rails3 will raise an (unexpected) RecordNotFound if there's only a nil group value
        r = Issue.visible.count(:joins => joins_for_order_statement(group_by_statement), :group => group_by_statement, :include => [:status, :project, :time_entries], :conditions => statement)
      rescue ActiveRecord::RecordNotFound
        r = {nil => issue_count}
      end
      c = group_by_column
      if c.is_a?(QueryCustomFieldColumn)
        r = r.keys.inject({}) { |h, k| h[c.custom_field.cast_value(k)] = r[k]; h }
      end
    end
    r
  rescue ::ActiveRecord::StatementInvalid => e
    raise StatementInvalid.new(e.message)
  end

  def query_joins(order_option)
    joins = []
    #joins = [:time_entries]
    for_order = joins_for_order_statement(order_option)
    joins << for_order unless for_order.nil?
    joins
  end

  def sql_for_time_spent_on_field(field, operator, value)
    '('+sql_for_field(field, operator, value, TimeEntry.table_name, 'spent_on')+')'
  end

  def sql_for_time_spent_user_id_field(field, operator, value)
    # "me" value subsitution
    if value.delete("me")
      if User.current.logged?
        value.push(User.current.id.to_s)
        value += User.current.group_ids.map(&:to_s) if field == 'assigned_to_id'
      else
        value.push("0")
      end
    end
    '('+sql_for_field(field, operator, value, TimeEntry.table_name, 'user_id')+')'
  end
end

#Issue.joins(:time_entries).where(time_entries: {created_on: Time.now.midnight..Time.now.midnight+1.day}).group("issues.id").select("issues.*, sum(time_entries.hours) as hours")