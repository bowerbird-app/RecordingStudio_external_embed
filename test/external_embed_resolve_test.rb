# frozen_string_literal: true

require "test_helper"

class ExternalEmbedResolveTest < Minitest::Test
  VIDEO_ID = "dQw4w9WgXcQ"
  EMBED_URL = "https://www.youtube-nocookie.com/embed/#{VIDEO_ID}".freeze
  CANONICAL_URL = "https://www.youtube.com/watch?v=#{VIDEO_ID}".freeze

  def test_watch_url_resolves_to_a_youtube_video
    embed = RecordingStudio::ExternalEmbed.resolve("https://www.youtube.com/watch?v=#{VIDEO_ID}")

    assert_equal true, embed.supported?
    assert_equal true, embed.valid?
    assert_equal [], embed.errors
    assert_nil embed.reason
    assert_equal :youtube, embed.provider
    assert_equal "YouTube", embed.provider_label
    assert_equal :video, embed.content_type
    assert_equal VIDEO_ID, embed.external_id
    assert_equal EMBED_URL, embed.embed_url
    assert_equal CANONICAL_URL, embed.canonical_url
    assert_equal "https://www.youtube.com/watch?v=#{VIDEO_ID}", embed.source_url
    assert_nil embed.title
    assert_nil embed.description
    assert_equal 560, embed.width
    assert_equal 315, embed.height
    assert_equal Rational(16, 9), embed.aspect_ratio
  end

  def test_accepted_youtube_urls_share_one_embed_url
    urls = [
      "https://youtube.com/watch?v=#{VIDEO_ID}",
      "http://www.youtube.com/watch?v=#{VIDEO_ID}",
      "https://www.youtube.com/watch?v=#{VIDEO_ID}&list=PL123&t=43s",
      "HTTPS://WWW.YOUTUBE.COM/watch?v=#{VIDEO_ID}",
      "https://www.youtube.com./watch?v=#{VIDEO_ID}",
      "https://m.youtube.com/watch?v=#{VIDEO_ID}",
      "https://youtu.be/#{VIDEO_ID}",
      "https://www.youtu.be/#{VIDEO_ID}?t=10",
      "https://www.youtube.com/shorts/#{VIDEO_ID}",
      "https://youtube.com/embed/#{VIDEO_ID}",
      "https://www.youtube.com/embed/#{VIDEO_ID}/"
    ]

    urls.each do |url|
      embed = RecordingStudio::ExternalEmbed.resolve(url)

      assert_equal EMBED_URL, embed.embed_url, url
      assert_equal VIDEO_ID, embed.external_id, url
      assert_equal :video, embed.content_type, url
    end
  end

  def test_shorts_use_a_portrait_ratio
    embed = RecordingStudio::ExternalEmbed.resolve("https://www.youtube.com/shorts/#{VIDEO_ID}")

    assert_equal Rational(9, 16), embed.aspect_ratio
    assert_equal 315, embed.width
    assert_equal 560, embed.height
  end

  def test_resolve_is_idempotent
    first = RecordingStudio::ExternalEmbed.resolve("https://youtu.be/#{VIDEO_ID}")
    second = RecordingStudio::ExternalEmbed.resolve("https://youtu.be/#{VIDEO_ID}")

    assert_equal first, second
  end

  def test_youtube_resolve_does_not_fetch
    RecordingStudio::ExternalEmbed.configuration.http = lambda do |_uri|
      flunk "YouTube resolve must not perform an HTTP request"
    end

    embed = RecordingStudio::ExternalEmbed.resolve("https://youtu.be/#{VIDEO_ID}")

    assert_equal EMBED_URL, embed.embed_url
  ensure
    RecordingStudio::ExternalEmbed.configuration.http = nil
  end

  def test_lookalike_hosts_are_unsupported
    [
      "https://youtube.com.evil.example/watch?v=#{VIDEO_ID}",
      "https://evil.example/watch?v=#{VIDEO_ID}",
      "https://notyoutube.com/embed/#{VIDEO_ID}",
      "https://youtu.be.evil.example/#{VIDEO_ID}"
    ].each do |url|
      result = RecordingStudio::ExternalEmbed.resolve(url)

      assert_equal false, result.supported?, url
      assert_equal false, result.valid?, url
      assert_equal :unsupported, result.reason, url
      assert_equal ["That URL is not from a supported provider."], result.errors, url
      refute_respond_to result, :embed_url
    end
  end

  def test_malformed_youtube_urls_do_not_build_an_embed_url
    [
      "https://www.youtube.com/watch",
      "https://www.youtube.com/watch?v=",
      "https://www.youtube.com/watch?v=short",
      "https://www.youtube.com/watch?v=abcdefghijkl",
      "https://youtu.be/#{VIDEO_ID}/extra",
      "https://www.youtube.com/playlist?list=PL123"
    ].each do |url|
      result = RecordingStudio::ExternalEmbed.resolve(url)

      assert_equal false, result.supported?, url
      assert_equal :malformed, result.reason, url
      assert_equal ["That URL is missing a valid id."], result.errors, url
      refute_respond_to result, :embed_url
    end
  end

  def test_unsafe_and_empty_inputs_are_invalid
    [
      nil,
      "",
      "   ",
      "javascript:alert(1)",
      "javascript:https://www.youtube.com/watch?v=#{VIDEO_ID}",
      "data:text/html,hi",
      "file:///etc/passwd",
      "https://user:pass@www.youtube.com/watch?v=#{VIDEO_ID}",
      "https://www.youtube.com:443/watch?v=#{VIDEO_ID}",
      "<iframe src=\"https://evil.example\"></iframe>",
      "not a url",
      12,
      "a" * 3000
    ].each do |input|
      result = RecordingStudio::ExternalEmbed.resolve(input)

      assert_equal false, result.supported?, input.inspect
      assert_equal :invalid, result.reason, input.inspect
      assert_equal ["That URL can't be embedded."], result.errors, input.inspect
      refute_respond_to result, :embed_url
    end
  end
end
