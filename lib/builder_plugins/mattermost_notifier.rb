class MattermostNotifier
  attr_accessor :hook_url
 
  def initialize(project = nil)
  end
 
  def build_finished(build)
    if build.failed? || (build.successful? && build.coverage_status_changed?)
      notify_of_build_outcome(build)
    end
  end
 
  def build_fixed(fixed_build, previous_build)
    notify_of_build_outcome(fixed_build, true)
  end
  
  def notify_of_build_outcome(build, fixed = nil)
    status = if build.failed?
      'broken'
    elsif fixed
      'fixed'
    else
      'successful'
    end
#    message = "#{build.project.name} build #{build.label} - **#{status.upcase}** #{status_icon(status)}"
    message = if Configuration.dashboard_url
      "[#{build.project.name} build #{build.label}](#{build.url})"
    else
      "#{build.project.name} build #{build.label}"
    end
    message << " - **#{status.upcase}** #{status_icon(status)}"
    if build.successful?
      message << " \n"
      message << coverage_delta_text(build.project)
    end
    CruiseControl::Log.debug("Mattermost notifier: sending 'build #{status}' notice")
    notify(message)
  end

  def notify(message)
    return unless hook_url
    begin
      CruiseControl::Log.debug("Mattermost notifier: sending notice: '#{message}'")
      HTTParty.post(hook_url, body: { payload: JSON.generate(text: message) })
    rescue => e
      CruiseControl::Log.debug("Mattermost notifier: #{e.message}")
    end
  end

  private
  
  def status_icon(status)
    chars = { 'broken' => [0x1F4A5, 0x1F64A, 0x1F648, 0x1F640, 0x1F621, 0x1F631],
              'fixed'  => [0x26BD, 0x1F60E, 0x1F638, 0x1F31F, 0x1F44D, 0x1F438, 0x1F438] }[status]
    return unless chars
    chars.shuffle.first.chr(Encoding::UTF_8)
  end
  
  def coverage_delta_text(project)
    delta = project.last_coverage_delta
    return '' if delta.abs < 0.25
    text = delta > 0 ? "Yay! Coverage increased by " : "Boo! Coverage decreased by "
    text << ("%0.1f%" % delta)
  end
end

Project.plugin :mattermost_notifier
