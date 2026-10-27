# frozen_string_literal: true

module RecordingStudio
  module ExternalEmbed
    class ApplicationController < ActionController::Base
      recording_studio_layout { RecordingStudio::ExternalEmbed.configuration.layout }

      protect_from_forgery with: :exception
    end
  end
end
