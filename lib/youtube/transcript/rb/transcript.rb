# frozen_string_literal: true

module Youtube
  module Transcript
    module Rb
      # Represents a language available for translation
      class TranslationLanguage
        # @return [String] the language name (e.g., "Spanish")
        attr_reader :language

        # @return [String] the language code (e.g., "es")
        attr_reader :language_code

        # @param language [String] the language name
        # @param language_code [String] the language code
        def initialize(language:, language_code:)
          @language = language
          @language_code = language_code
        end
      end

      # Represents a single transcript snippet/segment
      class TranscriptSnippet
        # @return [String] the text content of the snippet
        attr_reader :text

        # @return [Float] the start time in seconds
        attr_reader :start

        # @return [Float] the duration in seconds
        attr_reader :duration

        # @param text [String] the text content
        # @param start [Float] the start time in seconds
        # @param duration [Float] the duration in seconds
        def initialize(text:, start:, duration:)
          @text = text
          @start = start.to_f
          @duration = duration.to_f
        end

        # Convert to hash representation
        # @return [Hash] hash with text, start, and duration keys
        def to_h
          {
            "text" => @text,
            "start" => @start,
            "duration" => @duration
          }
        end
      end

      # Represents a fetched transcript containing multiple snippets
      # This class is Enumerable, allowing iteration over snippets
      class FetchedTranscript
        include Enumerable

        # @return [String] the video ID
        attr_reader :video_id

        # @return [String] the language name (e.g., "English")
        attr_reader :language

        # @return [String] the language code (e.g., "en")
        attr_reader :language_code

        # @return [Boolean] whether the transcript was auto-generated
        attr_reader :is_generated

        # @return [Array<TranscriptSnippet>] the transcript snippets
        attr_reader :snippets

        # @param video_id [String] the YouTube video ID
        # @param language [String] the language name
        # @param language_code [String] the language code
        # @param is_generated [Boolean] whether auto-generated
        # @param snippets [Array<TranscriptSnippet>] the snippets (optional)
        def initialize(video_id:, language:, language_code:, is_generated:, snippets: [])
          @video_id = video_id
          @language = language
          @language_code = language_code
          @is_generated = is_generated
          @snippets = snippets
        end

        # Add a snippet to the transcript
        # @param snippet [TranscriptSnippet] the snippet to add
        # @return [self]
        def add_snippet(snippet)
          @snippets << snippet
          self
        end

        # Iterate over each snippet
        # @yield [TranscriptSnippet] each snippet in the transcript
        def each(&block)
          @snippets.each(&block)
        end

        # Get a snippet by index
        # @param index [Integer] the index
        # @return [TranscriptSnippet] the snippet at the given index
        def [](index)
          @snippets[index]
        end

        # Get the number of snippets
        # @return [Integer] the count of snippets
        def length
          @snippets.length
        end
        alias size length

        # Convert to raw data (array of hashes)
        # @return [Array<Hash>] array of snippet hashes
        def to_raw_data
          @snippets.map(&:to_h)
        end

        # Check if transcript was auto-generated
        # @return [Boolean]
        def generated?
          @is_generated
        end
      end

      # Represents transcript metadata and provides fetch/translate capabilities
      class Transcript
        # @return [String] the video ID
        attr_reader :video_id

        # @return [String] the language name
        attr_reader :language

        # @return [String] the language code
        attr_reader :language_code

        # @return [Boolean] whether auto-generated
        attr_reader :is_generated

        # @return [Array<TranslationLanguage>] available translation languages
        attr_reader :translation_languages

        # @param http_client [Faraday::Connection] the HTTP client
        # @param video_id [String] the YouTube video ID
        # @param url [String] the transcript URL
        # @param language [String] the language name
        # @param language_code [String] the language code
        # @param is_generated [Boolean] whether auto-generated
        # @param translation_languages [Array<TranslationLanguage>] available translations
        def initialize(http_client:, video_id:, url:, language:, language_code:, is_generated:, translation_languages:)
          @http_client = http_client
          @video_id = video_id
          @url = url
          @language = language
          @language_code = language_code
          @is_generated = is_generated
          @translation_languages = translation_languages
          @translation_languages_dict = translation_languages.each_with_object({}) do |tl, hash|
            hash[tl.language_code] = tl.language
          end
        end

        # Fetch the actual transcript data
        # @param preserve_formatting [Boolean] whether to preserve HTML formatting
        # @return [FetchedTranscript] the fetched transcript
        # @raise [PoTokenRequired] if a PO token is required
        def fetch(preserve_formatting: false)
          raise PoTokenRequired, @video_id if @url.include?("&exp=xpe")

          response = @http_client.get(@url)
          raise_http_errors(response)

          parser = TranscriptParser.new(preserve_formatting: preserve_formatting)
          snippets = parser.parse(response.body)

          FetchedTranscript.new(
            video_id: @video_id,
            language: @language,
            language_code: @language_code,
            is_generated: @is_generated,
            snippets: snippets
          )
        end

        # Check if this transcript can be translated
        # @return [Boolean]
        def translatable?
          !@translation_languages.empty?
        end
        alias is_translatable translatable?

        # Translate this transcript to another language
        # @param language_code [String] the target language code
        # @return [Transcript] a new Transcript object for the translated version
        # @raise [NotTranslatable] if the transcript cannot be translated
        # @raise [TranslationLanguageNotAvailable] if the language is not available
        def translate(language_code)
          raise NotTranslatable, @video_id unless translatable?
          raise TranslationLanguageNotAvailable, @video_id unless @translation_languages_dict.key?(language_code)

          Transcript.new(
            http_client: @http_client,
            video_id: @video_id,
            url: "#{@url}&tlang=#{language_code}",
            language: @translation_languages_dict[language_code],
            language_code: language_code,
            is_generated: true,
            translation_languages: []
          )
        end

        # Check if transcript was auto-generated
        # @return [Boolean]
        def generated?
          @is_generated
        end

        # String representation of the transcript
        # @return [String]
        def to_s
          translation_desc = translatable? ? "[TRANSLATABLE]" : ""
          "#{@language_code} (\"#{@language}\")#{translation_desc}"
        end

        private

        def raise_http_errors(response)
          case response.status
          when 429
            raise IpBlocked, @video_id
          when 400..599
            raise YouTubeRequestFailed.new(@video_id, StandardError.new("HTTP #{response.status}"))
          end
        end
      end
    end
  end
end
