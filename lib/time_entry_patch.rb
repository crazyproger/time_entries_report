require_dependency 'time_entry'

module TimeEntryPatch
  def self.included(base)
    base.send(:include, InstanceMethods)
    base.class_eval do
      unloadable
    end
  end

  module InstanceMethods

    def total_hours
      @total_hours ||= -1
      end

    def total_hours=(total)
      @total_hours=total
    end

    def issue_author
      self.issue.author.name
    end
    def issue_assigned_to
      self.issue.try(:assigned_to).try(:name)
    end
    def issue_created_on
      self.issue.updated_on
    end
    def issue_updated_on
      self.issue.updated_on
    end
    def issue_due_date
      self.issue.due_date
    end
    def issue_estimated_hours
      self.issue.estimated_hours
    end
    def issue_category
      self.issue.try(:category).try(:name)
    end
    def issue_fixed_version
      self.issue.try(:fixed_version).try(:name)
    end
    def issue_subject
      self.issue.subject
    end
  end
end