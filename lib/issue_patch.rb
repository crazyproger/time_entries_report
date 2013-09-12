require_dependency 'issue'

module IssuePatch
  def self.included(base)
    base.send(:include, InstanceMethods)
    base.class_eval do
      unloadable
    end
  end

  module InstanceMethods
    def spent_hours_filtered
      @spent_hours_filtered ||= time_entries.to_a.map(&:hours).inject(0) {|x,y| x + y} || 0
    end
  end
end