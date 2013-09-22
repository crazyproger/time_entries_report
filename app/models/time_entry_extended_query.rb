class TimeEntryExtendedQuery < TimeEntryQuery

  def results_scope(options={})
    order_option = [group_by_sort_order, options[:order]].flatten.reject(&:blank?)

    TimeEntry.visible.
        where(statement).
        order(order_option).
        joins(joins_for_order_statement(order_option.join(',')))
  end

end
