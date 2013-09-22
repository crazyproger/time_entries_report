class TimeEntryExtendedQuery < TimeEntryQuery

  def results_scope(sort_clause)
    order_option = [group_by_sort_order, sort_clause].flatten.reject(&:blank?)

    TimeEntry.visible.
        where(statement).
        order(order_option).
        joins(joins_for_order_statement(order_option.join(',')))
  end

  def count(sort_clause)
    scope = results_scope(sort_clause)
    scope.select('user_id, issue_id').uniq.count
  end

  def entries(options = {})
    scope = results_scope(options.delete(:order)).includes(options.fetch(:include, [:project, :activity, :user, {:issue => :tracker}]))
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

end
