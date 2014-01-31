require 'json'

class GitlabHookController < ActionController::Base

  GIT_BIN = Redmine::Configuration['scm_git_command'] || "git"
  skip_before_filter :verify_authenticity_token, :check_if_login_required
  before_filter :check_enabled

  def index
    if request.post?
      repositories = find_repositories

      repositories.each do |repository|
        # Fetch the changes from GitLab
        update_repository(repository)

        # Fetch the new changesets into Redmine
        repository.fetch_changesets
      end
      render(:text => 'OK')
    else
      raise ActionController::RoutingError.new('Not Found')
    end    
  end

  private

  def system(command)
    Kernel.system(command)
  end

  # Executes shell command. Returns true if the shell command exits with a success status code
  def exec(command)
    logger.debug { "GitLabHook: Executing command: '#{command}'" }

    # Get a path to a temp file
    logfile = Tempfile.new('gitlab_hook_exec')
    logfile.close

    success = system("#{command} > #{logfile.path} 2>&1")
    output_from_command = File.readlines(logfile.path)
    if success
      logger.debug { "GitLabHook: Command output: #{output_from_command.inspect}"}
    else
      logger.error { "GitLabHook: Command '#{command}' didn't exit properly. Full output: #{output_from_command.inspect}"}
    end

    return success
  ensure
    logfile.unlink
  end

  def git_command(command, repository)
    GIT_BIN + " --git-dir='#{repository.url}' #{command}"
  end

  # Fetches updates from the remote repository
  def update_repository(repository)
    all_branches = Setting.plugin_redmine_gitlab_hook[:all_branches]
    all_branches = false if not all_branches
    if all_branches != "yes"
      command = git_command('fetch --all', repository)
      exec(command)
    else
      command = git_command('fetch origin', repository)
      if exec(command)
        command = git_command("fetch origin '+refs/heads/*:refs/heads/*'", repository)
        exec(command)
      end
    end
  end

  # Gets the project identifier from the querystring parameters and if that's not supplied, assume
  # the GitLab repository name is the same as the project identifier.
  def get_identifier
    payload = JSON.parse(params[:payload] || '{}')
    identifier = params[:project_id] || payload['repository']['name']
    raise ActiveRecord::RecordNotFound, "Project identifier not specified" if identifier.nil?
    return identifier
  end

  # Finds the Redmine project in the database based on the given project identifier
  def find_project
    identifier = get_identifier
    project = Project.find_by_identifier(identifier.downcase)
    raise ActiveRecord::RecordNotFound, "No project found with identifier '#{identifier}'" if project.nil?
    return project
  end

  # Returns the Redmine Repository object we are trying to update
  def find_repositories
    project = find_project
    repositories = project.repositories.select do |repo|
      repo.is_a?(Repository::Git)
    end

    if repositories.nil? or repositories.length == 0
      raise TypeError, "Project '#{project.to_s}' ('#{project.identifier}') has no repository"
    end

    return repositories
  end

  protected

  def check_enabled
    User.current = nil
    unless Setting.sys_api_enabled? && params[:key].to_s == Setting.sys_api_key
      render :text => 'Access denied. Repository management WS is disabled or key is invalid.', :status => 403
      return false
    end
  end

end
