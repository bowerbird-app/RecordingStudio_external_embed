# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require_relative "simplecov_helper"
require "minitest/autorun"
require "rails"
require "active_support/time"
Time.zone ||= "UTC"
require "recording_studio_external_embed"

module ExternalEmbedLiveHttpBlocked
  def fetch(uri)
    client = RecordingStudio::ExternalEmbed.configuration.http
    raise "oEmbed HTTP must be stubbed in tests" unless client

    client.call(uri)
  end
end

RecordingStudio::ExternalEmbed.const_get(:Oembed)::Gateway.prepend(ExternalEmbedLiveHttpBlocked)
