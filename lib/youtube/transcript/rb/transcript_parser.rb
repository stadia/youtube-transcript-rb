# frozen_string_literal: true

require "nokogiri"
require "cgi"

module Youtube
  module Transcript
    module Rb
      # Parses XML transcript data from YouTube
      class TranscriptParser
        # HTML formatting tags to preserve when preserve_formatting is enabled
        FORMATTING_TAGS = %w[
          strong
          em
          b
          i
          mark
          small
          del
          ins
          sub
          sup
        ].freeze

        # @param preserve_formatting [Boolean] whether to preserve HTML formatting tags
        def initialize(preserve_formatting: false)
          @preserve_formatting = preserve_formatting
          @html_regex = build_html_regex
        end

        # Parse XML transcript data into TranscriptSnippet objects
        # @param raw_data [String] the raw XML data from YouTube
        # @return [Array<TranscriptSnippet>] parsed transcript snippets
        def parse(raw_data)
          doc = Nokogiri::XML(raw_data)
          snippets = []

          doc.xpath("//text").each do |element|
            text_content = element.text
            next if text_content.nil? || text_content.empty?

            # Unescape HTML entities and remove unwanted HTML tags
            text = process_text(text_content)

            snippets << TranscriptSnippet.new(
              text: text,
              start: element["start"].to_f,
              duration: (element["dur"] || "0.0").to_f
            )
          end

          snippets
        end

        private

        # Build regex for removing HTML tags
        # @return [Regexp]
        def build_html_regex
          if @preserve_formatting
            # Remove all tags except formatting tags
            formats_pattern = FORMATTING_TAGS.join("|")
            # Match tags that are NOT the formatting tags
            Regexp.new("</?(?!/?(?:#{formats_pattern})\\b)[^>]*>", Regexp::IGNORECASE)
          else
            # Remove all HTML tags
            Regexp.new("<[^>]*>", Regexp::IGNORECASE)
          end
        end

        # Process text by unescaping HTML entities and removing unwanted tags
        # @param text [String] the raw text
        # @return [String] processed text
        def process_text(text)
          # Unescape HTML entities
          unescaped = CGI.unescapeHTML(text)
          # Remove unwanted HTML tags
          unescaped.gsub(@html_regex, "")
        end
      end
    end
  end
end
