RedmineApp::Application.routes.draw do
  match 'gitlab_hook', :to => 'gitlab_hook#index', :via => [:get, :post]
end
