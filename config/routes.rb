RedmineApp::Application.routes.draw do
  match 'gitlab_hook' => 'gitlab_hook#index', :via => [:post]
  match 'gitlab_hook' => 'gitlab_hook#index', :via => [:get]
end
