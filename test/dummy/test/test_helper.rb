# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

require_relative "../config/environment"
require "rails/test_help"

module ExternalEmbedLiveHttpBlocked
  def fetch(uri)
    client = RecordingStudio::ExternalEmbed.configuration.http
    raise "oEmbed HTTP must be stubbed in tests" unless client

    client.call(uri)
  end
end

RecordingStudio::ExternalEmbed.const_get(:Oembed)::Gateway.prepend(ExternalEmbedLiveHttpBlocked)
