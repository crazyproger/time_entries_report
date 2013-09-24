require 'issue_patch'
Issue.send(:include, IssuePatch)
require 'time_entry_patch'
TimeEntry.send(:include, TimeEntryPatch)

require 'redmine'

Redmine::Plugin.register :time_entries_report do
  name 'Time Entries Report plugin'
  author 'crazyproger'
  description 'This is a plugin for Redmine. It adds custom(or more redmine-like) reports to issue time entries.'
  version '0.0.1'
  url 'https://github.com/crazyproger/time_entries_report'
  author_url 'https://github.com/crazyproger'
end

RedmineApp::Application.routes.prepend do
  get '/projects/:project_id/time_entries/detailed', to: 'detailed_query#detailed', as: 'with_project'
  get '/projects/:project_id/time_entries/detailed_time_log', to: 'detailed_query#detailed_time_log', as: 'detailed_with_project'
  get '/time_entries/detailed', to: 'detailed_query#detailed'
  get '/time_entries/detailed_time_log', to: 'detailed_query#detailed_time_log'
end
