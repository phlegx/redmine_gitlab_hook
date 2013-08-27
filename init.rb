require 'redmine'

Redmine::Plugin.register :redmine_gitlab_hook do
  name 'Redmine GitLab Hook plugin'
  author 'Phlegx Systems'
  description 'This plugin allows your Redmine installation to receive GitLab post-receive notifications'
  version '0.0.1'
  url 'https://github.com/phlegx/redmine_gitlab_hook'
  author_url 'https://github.com/phlegx'
  
  settings :default => { :all_branches => "yes" }, :partial => 'settings/gitlab_settings'
end
