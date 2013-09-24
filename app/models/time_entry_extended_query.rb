class TimeEntryExtendedQuery < TimeEntryQuery

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

  def results_scope(sort_clause)
    order_option = [group_by_sort_order, sort_clause].flatten.reject(&:blank?)

    TimeEntry.visible.
        where(statement).
        order(order_option).
        joins(joins_for_order_statement(order_option.join(','))).
        includes(:issue => :tracker)
  end

  def count(sort_clause)
    scope = results_scope(sort_clause)
    scope.select('user_id, issue_id').uniq.count
  end

  def entries(options = {})
    scope = results_scope(options.delete(:order)).includes(options.fetch(:include, [:project, :activity, :user]))
    options.delete(:include)
    grouped = scope.group(:user_id, :issue_id)
    time_entries = grouped.clone.all(options)
    times = grouped.clone.sum(:hours)
    load_hours_to_entries(time_entries, times)
    time_entries
  end

  def load_hours_to_entries(entries, times)
    if entries.any?
      entries.each do |entry|
        entry.hours=times[[entry.user_id, entry.issue_id]]
      end
    end
  end

  def sql_for_fixed_version_id_field(field, operator, value)
    '('+sql_for_field(field, operator, value, Issue.table_name, 'fixed_version_id')+')'
  end

end
