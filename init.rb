require 'redmine'

Redmine::Plugin.register :redmine_gitlab_hook do
  name 'Redmine GitLab Hook plugin'
  author 'Phlegx Systems'
  description 'This plugin allows your Redmine installation to receive GitLab post-receive notifications'
  version '4.0.0'
  url 'https://github.com/phlegx/redmine_gitlab_hook'
  author_url 'https://github.com/phlegx'
  requires_redmine :version_or_higher => '3.0.0'

  settings :default => { 
    :all_branches => 'yes', 
    :prune => 'yes', 
    :auto_create => 'yes', 
    :fetch_updates => 'yes' 
  }, :partial => 'settings/gitlab_settings'
end
