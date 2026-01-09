# frozen_string_literal: true

module YoutubeRb
  module Transcript
    # Represents a list of available transcripts for a YouTube video.
    # This class is Enumerable, allowing iteration over all available transcripts.
    # It provides functionality to search for transcripts in specific languages.
    class TranscriptList
      include Enumerable

      # @return [String] the video ID this TranscriptList is for
      attr_reader :video_id

      # Build a TranscriptList from captions JSON data
      #
      # @param http_client [Faraday::Connection] the HTTP client for fetching transcripts
      # @param video_id [String] the YouTube video ID
      # @param captions_json [Hash] the captions JSON parsed from YouTube
      # @return [TranscriptList] the created TranscriptList
      def self.build(http_client:, video_id:, captions_json:)
        translation_languages = (captions_json["translationLanguages"] || []).map do |tl|
          TranslationLanguage.new(
            language: tl.dig("languageName", "runs", 0, "text") || "",
            language_code: tl["languageCode"]
          )
        end

        manually_created_transcripts = {}
        generated_transcripts = {}

        (captions_json["captionTracks"] || []).each do |caption|
          is_generated = caption.fetch("kind", "") == "asr"
          target_dict = is_generated ? generated_transcripts : manually_created_transcripts

          language_code = caption["languageCode"]
          transcript_translation_languages = caption.fetch("isTranslatable", false) ? translation_languages : []

          target_dict[language_code] = TranscriptMetadata.new(
            http_client: http_client,
            video_id: video_id,
            url: caption["baseUrl"].to_s.gsub("&fmt=srv3", ""),
            language: caption.dig("name", "runs", 0, "text") || "",
            language_code: language_code,
            is_generated: is_generated,
            translation_languages: transcript_translation_languages
          )
        end

        new(
          video_id: video_id,
          manually_created_transcripts: manually_created_transcripts,
          generated_transcripts: generated_transcripts,
          translation_languages: translation_languages
        )
      end

      # @param video_id [String] the YouTube video ID
      # @param manually_created_transcripts [Hash<String, TranscriptMetadata>] manually created transcripts by language code
      # @param generated_transcripts [Hash<String, TranscriptMetadata>] auto-generated transcripts by language code
      # @param translation_languages [Array<TranslationLanguage>] available translation languages
      def initialize(video_id:, manually_created_transcripts:, generated_transcripts:, translation_languages:)
        @video_id = video_id
        @manually_created_transcripts = manually_created_transcripts
        @generated_transcripts = generated_transcripts
        @translation_languages = translation_languages
      end

      # Iterate over all transcripts (manually created first, then generated)
      #
      # @yield [TranscriptMetadata] each available transcript
      # @return [Enumerator] if no block given
      def each(&)
        return to_enum(:each) unless block_given?

        @manually_created_transcripts.each_value(&)
        @generated_transcripts.each_value(&)
      end

      # Find a transcript for the given language codes.
      # Manually created transcripts are preferred over generated ones.
      #
      # @param language_codes [Array<String>] language codes in descending priority
      # @return [TranscriptMetadata] the found transcript
      # @raise [NoTranscriptFound] if no transcript matches the requested languages
      def find_transcript(language_codes)
        find_transcript_in(
          language_codes,
          [@manually_created_transcripts, @generated_transcripts]
        )
      end

      # Find an automatically generated transcript for the given language codes.
      #
      # @param language_codes [Array<String>] language codes in descending priority
      # @return [TranscriptMetadata] the found transcript
      # @raise [NoTranscriptFound] if no generated transcript matches
      def find_generated_transcript(language_codes)
        find_transcript_in(language_codes, [@generated_transcripts])
      end

      # Find a manually created transcript for the given language codes.
      #
      # @param language_codes [Array<String>] language codes in descending priority
      # @return [TranscriptMetadata] the found transcript
      # @raise [NoTranscriptFound] if no manually created transcript matches
      def find_manually_created_transcript(language_codes)
        find_transcript_in(language_codes, [@manually_created_transcripts])
      end

      # String representation of the transcript list
      #
      # @return [String] human-readable description of available transcripts
      def to_s
        <<~DESC
          For this video (#{@video_id}) transcripts are available in the following languages:

          (MANUALLY CREATED)
          #{format_language_list(@manually_created_transcripts.values)}

          (GENERATED)
          #{format_language_list(@generated_transcripts.values)}

          (TRANSLATION LANGUAGES)
          #{format_translation_languages}
        DESC
      end

      private

      # Find a transcript from the given dictionaries
      #
      # @param language_codes [Array<String>] language codes to search for
      # @param transcript_dicts [Array<Hash>] transcript dictionaries to search
      # @return [TranscriptMetadata] the found transcript
      # @raise [NoTranscriptFound] if no transcript matches
      def find_transcript_in(language_codes, transcript_dicts)
        language_codes.each do |language_code|
          transcript_dicts.each do |dict|
            return dict[language_code] if dict.key?(language_code)
          end
        end

        raise NoTranscriptFound.new(@video_id, language_codes, self)
      end

      # Format a list of transcripts for display
      #
      # @param transcripts [Array<TranscriptMetadata>] transcripts to format
      # @return [String] formatted list or "None"
      def format_language_list(transcripts)
        return "None" if transcripts.empty?

        transcripts.map { |t| " - #{t}" }.join("\n")
      end

      # Format translation languages for display
      #
      # @return [String] formatted list or "None"
      def format_translation_languages
        return "None" if @translation_languages.empty?

        @translation_languages.map do |tl|
          " - #{tl.language_code} (\"#{tl.language}\")"
        end.join("\n")
      end
    end
  end
end
