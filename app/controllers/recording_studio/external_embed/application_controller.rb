# frozen_string_literal: true

module RecordingStudio
  module ExternalEmbed
    class ApplicationController < ActionController::Base
      protect_from_forgery with: :exception
    end
  end
end
