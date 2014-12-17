require 'json'

class GitlabHookController < ActionController::Base

  GIT_BIN = Redmine::Configuration['scm_git_command'] || 'git'
  skip_before_filter :verify_authenticity_token, :check_if_login_required


  def index
    if request.post?
      repositories = find_repositories
      if repositories.empty?
        render(text: 'No repository configured!', status: :not_found)
      else
        errors = []
        repositories.each do |repository|
          # Fetch the changes from GitLab
          git_success = update_repository(repository)
          unless git_success
            errors.push(repository.identifier)
          else
            # Fetch the new changesets into Redmine
            repository.fetch_changesets
          end
        end
        if errors.empty?
          render(text: 'OK', status: :ok)
        else
          render(text: "Git command failed on repository: #{errors.join(', ')}!", status: :not_acceptable)
        end
      end
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
    Setting.plugin_redmine_gitlab_hook['prune'] == 'yes' ? prune = ' -p' : prune = ''
    if Setting.plugin_redmine_gitlab_hook['all_branches'] == 'yes'
      command = git_command("fetch --all#{prune}", repository)
      exec(command)
    else
      command = git_command("fetch#{origin} origin", repository)
      if exec(command) 
        command = git_command("fetch#{prune} origin '+refs/heads/*:refs/heads/*'", repository)
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

end
