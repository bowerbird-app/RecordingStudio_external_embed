# frozen_string_literal: true

require "test_helper"

class ExternalEmbedHelperTest < Minitest::Test
  VIDEO_ID = "dQw4w9WgXcQ"
  EMBED_URL = "https://www.youtube-nocookie.com/embed/#{VIDEO_ID}".freeze

  class View
    include RecordingStudio::ExternalEmbed::Helper
  end

  def setup
    @view = View.new
  end

  def test_render_builds_a_responsive_iframe_from_a_resolved_embed
    embed = RecordingStudio::ExternalEmbed.resolve("https://youtu.be/#{VIDEO_ID}")
    html = @view.recording_studio_external_embed(embed)

    assert_equal true, html.html_safe?
    assert_includes html, "aspect-ratio:16 / 9"
    assert_includes html, "width:100%"
    assert_includes html, %(src="#{EMBED_URL}")
    assert_includes html, 'title="YouTube embed"'
    assert_includes html, 'loading="lazy"'
    assert_includes html, 'referrerpolicy="strict-origin-when-cross-origin"'
    assert_includes html, 'allow="fullscreen; picture-in-picture; encrypted-media"'
    assert_includes html, 'allowfullscreen="allowfullscreen"'
    refute_includes html, "sandbox"
    refute_includes html, "accelerometer"
    refute_includes html, "clipboard-write"
    refute_includes html, "autoplay"
    refute_includes html, "https://www.youtube.com/watch"
    refute_includes html, "youtu.be"
  end

  def test_render_accepts_a_url_string
    html = @view.recording_studio_external_embed("https://www.youtube.com/shorts/#{VIDEO_ID}")

    assert_includes html, "aspect-ratio:9 / 16"
    assert_includes html, %(src="#{EMBED_URL}")
  end

  def test_render_of_unsupported_input_is_empty_and_does_not_echo_it
    inputs = [
      "javascript:alert(1)",
      "<iframe src=\"https://evil.example\"></iframe><script>alert(1)</script>",
      "https://youtube.com.evil.example/watch?v=#{VIDEO_ID}",
      nil
    ]

    inputs.each do |input|
      html = @view.recording_studio_external_embed(input)

      assert_equal "", html, input.inspect
      assert_equal true, html.html_safe?, input.inspect
      refute_includes html, "iframe", input.inspect
      refute_includes html, "script", input.inspect
      refute_includes html, "evil", input.inspect
      refute_includes html, "javascript", input.inspect
    end
  end

  def test_render_escapes_a_provider_title
    provider = clip_provider
    RecordingStudio::ExternalEmbed.configuration.resolver = ->(_host) { ["1.1.1.1"] }
    RecordingStudio::ExternalEmbed.configuration.http = lambda do |_uri|
      payload = {
        "title" => '"><script>alert(1)</script>',
        "html" => "<iframe src=\"https://evil.example\"></iframe>"
      }
      [200, payload.to_json]
    end

    html = RecordingStudio::ExternalEmbed.with_providers(provider) do
      @view.recording_studio_external_embed("https://clips.test/v/abcd1234")
    end

    assert_includes html, %(src="https://play.clips.test/e/abcd1234")
    refute_includes html, "<script"
    refute_includes html, "evil.example"
    assert_includes html, "&quot;"
  ensure
    RecordingStudio::ExternalEmbed.configuration.http = nil
    RecordingStudio::ExternalEmbed.configuration.resolver = nil
  end

  def clip_provider
    RecordingStudio::ExternalEmbed::Provider.define(:clip) do
      host "clips.test"
      label "Clip"
      embed_host "play.clips.test"
      embeds_as "https://play.clips.test/e/{id}"
      canonical "https://clips.test/v/{id}"
      oembed endpoint: "https://oembed.clips.test/oembed", thumbnail_hosts: ["img.clips.test"]
      match content_type: :video, aspect: Rational(16, 9) do
        path %r{\A/v/(?<id>[a-z0-9]{8})\z}
      end
    end
  end
end
