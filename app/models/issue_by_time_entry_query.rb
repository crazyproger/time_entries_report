class IssueByTimeEntryQuery < IssueQuery
  def results_scope(options={})
    order_option = [group_by_sort_order, options[:order]].flatten.reject(&:blank?)

    Issue.visible.
        where(statement).
        order(order_option).
        joins(joins_for_order_statement(order_option.join(',')))
  end
end

#Issue.joins(:time_entries).where(time_entries: {created_on: Time.now.midnight..Time.now.midnight+1.day}).group("issues.id").select("issues.*, sum(time_entries.hours) as hours")