class ApplicationController < ActionController::Base
  include RecordingStudio::RootSwitchable::ControllerSupport

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  recording_studio_layout { devise_controller? ? "application" : RecordingStudio::ExternalEmbed.configuration.layout }

  before_action :authenticate_user!
  before_action :set_current_actor

  private

  # Root Switchable v0.9.0 calls this method when config.layout is :application_layout.
  def application_layout
    recording_studio_resolved_layout
  end

  def set_current_actor
    Current.actor = current_user
  end
end
