# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html
#resources :time_entries, :controller => 'timelog', :except => :destroy do
#  collection do
#    get 'detailed'
#  end
#end

#get '/time_entries/detailed', to: 'timelog#detailed'

match  '/detailed', :to => 'timelog#detailed', :via => [:get]
#match  '/time_entries/detailed', :to => 'timelog#detailed', :via => [:get]
#RedmineApp::Application.routes.draw do
#  match  '/time_entries/detailed', :to => 'timelog#detailed', :via => [:get]
#end