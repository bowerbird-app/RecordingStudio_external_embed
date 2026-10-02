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
    embed = RecordingStudio::ExternalEmbed.resolve("https://vimeo.com/524933864")

    assert embed.supported?
    assert_equal :vimeo, embed.provider
    assert_equal "https://player.vimeo.com/video/524933864", embed.embed_url
  end

  test "dummy sample wistia watch url resolves via wmediaid to iframe embed" do
    embed = RecordingStudio::ExternalEmbed.resolve(
      "https://wistia.com/watch/video-strategy?wchannelid=7bl63kge0w&wmediaid=x10zt19irk"
    )

    assert embed.supported?
    assert_equal :wistia, embed.provider
    assert_equal "https://fast.wistia.net/embed/iframe/x10zt19irk", embed.embed_url
    assert_equal "https://wistia.com/medias/x10zt19irk", embed.canonical_url
  end

  test "dummy twitch embed urls include parent hosts for iframe embedding" do
    vod = RecordingStudio::ExternalEmbed.resolve("https://www.twitch.tv/videos/456031513")
    clip = RecordingStudio::ExternalEmbed.resolve(
      "https://clips.twitch.tv/AmazonianIntentDiamondPhilosoraptor-eWblKfNOah8BsKjW"
    )

    assert_includes vod.embed_url, "parent=ripeness-unreached-wham.ngrok-free.dev"
    assert_includes clip.embed_url, "parent=ripeness-unreached-wham.ngrok-free.dev"
  end
end
