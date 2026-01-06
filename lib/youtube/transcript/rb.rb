# frozen_string_literal: true

require_relative "rb/version"
require_relative "rb/settings"
require_relative "rb/errors"
require_relative "rb/transcript_parser"
require_relative "rb/transcript"
require_relative "rb/transcript_list"
require_relative "rb/transcript_list_fetcher"
require_relative "rb/api"

module Youtube
  module Transcript
    module Rb
      class << self
        # Convenience method to fetch a transcript
        # @param video_id [String] YouTube video ID
        # @param languages [Array<String>] Language codes in order of preference
        # @param preserve_formatting [Boolean] Whether to preserve HTML formatting
        # @return [FetchedTranscript] The fetched transcript
        def fetch(video_id, languages: ["en"], preserve_formatting: false)
          api = YouTubeTranscriptApi.new
          api.fetch(video_id, languages: languages, preserve_formatting: preserve_formatting)
        end

        # Convenience method to list available transcripts
        # @param video_id [String] YouTube video ID
        # @return [TranscriptList] List of available transcripts
        def list(video_id)
          api = YouTubeTranscriptApi.new
          api.list(video_id)
        end
      end
    end
  end
end
