# frozen_string_literal: true

require "erb"
require "active_support/core_ext/string/output_safety"

module RecordingStudio
  module ExternalEmbed
    module Helper
      ALLOW = "fullscreen; picture-in-picture; encrypted-media"
      IFRAME_STYLE = "position:absolute;top:0;right:0;bottom:0;left:0;width:100%;height:100%;border:0;"

      def recording_studio_external_embed(value)
        result = value.is_a?(Embed) || value.is_a?(Unresolved) ? value : ExternalEmbed.resolve(value)
        return "".html_safe unless result.is_a?(Embed)

        external_embed_markup(result).html_safe
      end

      private

      def external_embed_markup(embed)
        ratio = "#{embed.aspect_ratio.numerator} / #{embed.aspect_ratio.denominator}"
        src = ERB::Util.html_escape(embed.embed_url)
        title = ERB::Util.html_escape(external_embed_title(embed))
        <<~HTML
          <div class="recording-studio-external-embed" style="position:relative;width:100%;aspect-ratio:#{ratio};">
            <iframe src="#{src}" title="#{title}" loading="lazy" referrerpolicy="strict-origin-when-cross-origin" allow="#{ALLOW}" allowfullscreen="allowfullscreen" style="#{IFRAME_STYLE}"></iframe>
          </div>
        HTML
      end

      def external_embed_title(embed)
        text = embed.title.to_s.strip
        text.empty? ? "#{embed.provider_label} embed" : text
      end
    end
  end
end
