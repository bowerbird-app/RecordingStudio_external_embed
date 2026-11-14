# frozen_string_literal: true

require "test_helper"

class ExternalEmbedProviderTest < Minitest::Test
  def test_a_registered_provider_resolves_without_editing_youtube
    embed = RecordingStudio::ExternalEmbed.with_providers(fixture_provider) do
      RecordingStudio::ExternalEmbed.resolve("https://videos.test/v/abcd1234")
    end

    assert_equal true, embed.supported?
    assert_equal :fixture, embed.provider
    assert_equal "abcd1234", embed.external_id
    assert_equal "https://play.videos.test/e/abcd1234", embed.embed_url
    assert_equal "https://videos.test/v/abcd1234", embed.canonical_url
  end

  def test_replacing_providers_removes_the_built_in_youtube_catalog
    result = RecordingStudio::ExternalEmbed.with_providers(fixture_provider, replace: true) do
      RecordingStudio::ExternalEmbed.resolve("https://youtu.be/dQw4w9WgXcQ")
    end

    assert_equal false, result.supported?
    assert_equal :unsupported, result.reason
    restored = RecordingStudio::ExternalEmbed.resolve("https://youtu.be/dQw4w9WgXcQ")
    assert_equal "https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ", restored.embed_url
  end

  def test_register_rejects_a_duplicate_host
    provider = fixture_provider
    RecordingStudio::ExternalEmbed.register(provider)

    error = assert_raises(RecordingStudio::ExternalEmbed::Conflict) do
      RecordingStudio::ExternalEmbed.register(fixture_provider)
    end

    assert_equal "provider is already registered", error.message
  ensure
    reset_catalog!
  end

  def test_a_match_clause_can_override_the_default_embed_template
    provider = RecordingStudio::ExternalEmbed::Provider.define(:dual_embed) do
      host "videos.test"
      embed_host "play.videos.test", "alt.play.videos.test"
      embeds_as "https://play.videos.test/e/{id}"
      canonical "https://videos.test/v/{id}"
      match content_type: :video, aspect: Rational(16, 9) do
        path %r{\A/v/(?<id>[a-z0-9]{8})\z}
        path %r{\A/alt/(?<id>[a-z0-9]{8})\z}, embeds_as: "https://alt.play.videos.test/e/{id}"
      end
    end

    default_embed = RecordingStudio::ExternalEmbed.with_providers(provider) do
      RecordingStudio::ExternalEmbed.resolve("https://videos.test/v/abcd1234")
    end
    alt_embed = RecordingStudio::ExternalEmbed.with_providers(provider) do
      RecordingStudio::ExternalEmbed.resolve("https://videos.test/alt/abcd1234")
    end

    assert_equal "https://play.videos.test/e/abcd1234", default_embed.embed_url
    assert_equal "https://alt.play.videos.test/e/abcd1234", alt_embed.embed_url
  end

  def test_a_hash_placeholder_requires_a_clause_that_captures_a_hash
    error = assert_raises(RecordingStudio::ExternalEmbed::DefinitionError) do
      RecordingStudio::ExternalEmbed::Provider.define(:bad_hash) do
        host "videos.test"
        embed_host "play.videos.test"
        embeds_as "https://play.videos.test/e/{id}?h={hash}"
        canonical "https://videos.test/v/{id}/{hash}"
        match content_type: :video, aspect: Rational(16, 9) do
          path %r{\A/v/(?<id>[a-z0-9]{8})\z}
        end
      end
    end

    assert_equal "template hash does not match the clause", error.message
  end

  def test_a_hash_capture_requires_one_hash_placeholder
    error = assert_raises(RecordingStudio::ExternalEmbed::DefinitionError) do
      RecordingStudio::ExternalEmbed::Provider.define(:missing_hash) do
        host "videos.test"
        embed_host "play.videos.test"
        embeds_as "https://play.videos.test/e/{id}"
        canonical "https://videos.test/v/{id}"
        match content_type: :video, aspect: Rational(16, 9) do
          path %r{\A/v/(?<id>[a-z0-9]{8})/(?<hash>[a-z0-9]{4})\z},
               embeds_as: "https://play.videos.test/e/{id}",
               canonical: "https://videos.test/v/{id}"
        end
      end
    end

    assert_equal "template hash does not match the clause", error.message
  end

  def test_a_template_rejects_a_second_hash_placeholder
    error = assert_raises(RecordingStudio::ExternalEmbed::DefinitionError) do
      RecordingStudio::ExternalEmbed::Provider.define(:two_hashes) do
        host "videos.test"
        embed_host "play.videos.test"
        embeds_as "https://play.videos.test/{hash}/e/{id}?h={hash}"
        canonical "https://videos.test/v/{id}"
        match content_type: :video, aspect: Rational(16, 9) do
          path %r{\A/v/(?<id>[a-z0-9]{8})\z}
        end
      end
    end

    assert_equal "template must contain one hash", error.message
  end

  def test_a_hash_cannot_move_the_template_onto_another_host
    error = assert_raises(RecordingStudio::ExternalEmbed::DefinitionError) do
      RecordingStudio::ExternalEmbed::Provider.define(:hash_host) do
        host "videos.test"
        embed_host "play.videos.test"
        embeds_as "https://{hash}.videos.test/e/{id}"
        canonical "https://videos.test/v/{id}"
        match content_type: :video, aspect: Rational(16, 9) do
          path %r{\A/v/(?<id>[a-z0-9]{8})/(?<hash>[a-z0-9]{4})\z},
               embeds_as: "https://play.videos.test/e/{id}?h={hash}",
               canonical: "https://videos.test/v/{id}/{hash}"
        end
      end
    end

    assert_equal "template is not a trusted https url", error.message
  end

  def test_a_hash_query_pattern_must_be_anchored
    error = assert_raises(RecordingStudio::ExternalEmbed::DefinitionError) do
      RecordingStudio::ExternalEmbed::Provider.define(:loose_hash) do
        host "videos.test"
        embed_host "play.videos.test"
        embeds_as "https://play.videos.test/e/{id}"
        canonical "https://videos.test/v/{id}"
        match content_type: :video, aspect: Rational(16, 9) do
          path %r{\A/v/(?<id>[a-z0-9]{8})\z}, hash_param: "h", hash_pattern: /[a-z0-9]+/
        end
      end
    end

    assert_equal "hash pattern must be anchored", error.message
  end

  def test_a_thumbnail_template_can_only_use_a_declared_thumbnail_host
    error = assert_raises(RecordingStudio::ExternalEmbed::DefinitionError) do
      RecordingStudio::ExternalEmbed::Provider.define(:bad) do
        host "videos.test"
        embed_host "play.videos.test"
        thumbnail_host "i.ytimg.com"
        embeds_as "https://play.videos.test/e/{id}"
        canonical "https://videos.test/v/{id}"
        thumbnail "https://i.ytimg.com.evil.example/vi/{id}/hqdefault.jpg"
        match content_type: :video, aspect: Rational(16, 9) do
          path %r{\A/v/(?<id>[a-z0-9]{8})\z}
        end
      end
    end

    assert_equal "template is not a trusted https url", error.message
  end

  def test_a_paste_or_embed_host_is_not_a_thumbnail_host
    ["https://videos.test/t/{id}.jpg", "https://play.videos.test/t/{id}.jpg"].each do |template|
      error = assert_raises(RecordingStudio::ExternalEmbed::DefinitionError) do
        RecordingStudio::ExternalEmbed::Provider.define(:bad) do
          host "videos.test"
          embed_host "play.videos.test"
          thumbnail_host "i.ytimg.com"
          embeds_as "https://play.videos.test/e/{id}"
          canonical "https://videos.test/v/{id}"
          thumbnail template
          match content_type: :video, aspect: Rational(16, 9) do
            path %r{\A/v/(?<id>[a-z0-9]{8})\z}
          end
        end
      end

      assert_equal "template is not a trusted https url", error.message, template
    end
  end

  def test_a_thumbnail_host_cannot_be_used_as_the_iframe_host
    error = assert_raises(RecordingStudio::ExternalEmbed::DefinitionError) do
      RecordingStudio::ExternalEmbed::Provider.define(:bad) do
        host "videos.test"
        thumbnail_host "i.ytimg.com"
        embeds_as "https://i.ytimg.com/vi/{id}/hqdefault.jpg"
        canonical "https://videos.test/v/{id}"
        thumbnail "https://i.ytimg.com/vi/{id}/hqdefault.jpg"
        match content_type: :video, aspect: Rational(16, 9) do
          path %r{\A/v/(?<id>[a-z0-9]{8})\z}
        end
      end
    end

    assert_equal "template is not a trusted https url", error.message
  end

  def test_a_template_cannot_point_the_iframe_at_an_undeclared_host
    error = assert_raises(RecordingStudio::ExternalEmbed::DefinitionError) do
      RecordingStudio::ExternalEmbed::Provider.define(:bad) do
        host "videos.test"
        embeds_as "https://evil.example/e/{id}"
        canonical "https://videos.test/v/{id}"
        match content_type: :video, aspect: Rational(16, 9) do
          path %r{\A/v/(?<id>[a-z0-9]{8})\z}
        end
      end
    end

    assert_equal "template is not a trusted https url", error.message
  end

  def test_freeze_blocks_later_registration
    RecordingStudio::ExternalEmbed.freeze_catalog!

    assert_raises(RecordingStudio::ExternalEmbed::Conflict) do
      RecordingStudio::ExternalEmbed.register(fixture_provider)
    end
  ensure
    reset_catalog!
  end

  def fixture_provider
    RecordingStudio::ExternalEmbed::Provider.define(:fixture) do
      host "videos.test"
      label "Fixture"
      embed_host "play.videos.test"
      embeds_as "https://play.videos.test/e/{id}"
      canonical "https://videos.test/v/{id}"
      match content_type: :video, aspect: Rational(16, 9) do
        path %r{\A/v/(?<id>[a-z0-9]{8})\z}
      end
    end
  end

  def reset_catalog!
    RecordingStudio::ExternalEmbed.instance_variable_set(:@providers, nil)
    RecordingStudio::ExternalEmbed.instance_variable_set(:@catalog, nil)
    RecordingStudio::ExternalEmbed.instance_variable_set(:@catalog_frozen, false)
  end
end
