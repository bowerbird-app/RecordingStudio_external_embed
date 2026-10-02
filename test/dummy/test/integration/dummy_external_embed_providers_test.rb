# frozen_string_literal: true

require "test_helper"

class DummyExternalEmbedProvidersTest < ActiveSupport::TestCase
  test "dummy initializer registers extra providers alongside youtube" do
    keys = RecordingStudio::ExternalEmbed.send(:providers).map(&:key)

    assert_includes keys, :youtube
    assert_includes keys, :vimeo
    assert_includes keys, :loom
    assert_includes keys, :wistia
    assert_includes keys, :brightcove
    assert_includes keys, :dailymotion
    assert_includes keys, :twitch
    assert_includes keys, :twitch_clip
  end

  test "dummy sample vimeo url resolves to player embed" do
    embed = RecordingStudio::ExternalEmbed.resolve("https://vimeo.com/148751763")

    assert embed.supported?
    assert_equal :vimeo, embed.provider
    assert_equal "https://player.vimeo.com/video/148751763", embed.embed_url
  end
end
