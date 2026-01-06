# frozen_string_literal: true

module YoutubeRb
  module Transcript
    # Base error class for all YouTube Transcript errors
    class Error < StandardError; end

    # Raised when a transcript could not be retrieved
    class CouldNotRetrieveTranscript < Error
      WATCH_URL = "https://www.youtube.com/watch?v=%<video_id>s"

      # @return [String] the video ID that caused the error
      attr_reader :video_id

      # @param video_id [String] the YouTube video ID
      def initialize(video_id)
        @video_id = video_id
        super(build_error_message)
      end

      # @return [String] the cause of the error
      def cause_message
        self.class::CAUSE_MESSAGE
      end

      private

      def build_error_message
        video_url = format(WATCH_URL, video_id: @video_id)
        message = "\nCould not retrieve a transcript for the video #{video_url}!"

        if cause_message && !cause_message.empty?
          message += " This is most likely caused by:\n\n#{cause_message}"
          message += github_referral
        end

        message
      end

      def github_referral
        "\n\nIf you are sure that the described cause is not responsible for this error " \
          "and that a transcript should be retrievable, please create an issue at " \
          "https://github.com/jdepoix/youtube-transcript-api/issues. " \
          "Please add which version of youtube_transcript_api you are using " \
          "and provide the information needed to replicate the error. " \
          "Also make sure that there are no open issues which already describe your problem!"
      end
    end

    # Raised when YouTube data cannot be parsed
    class YouTubeDataUnparsable < CouldNotRetrieveTranscript
      CAUSE_MESSAGE = "The data required to fetch the transcript is not parsable. This should " \
                      "not happen, please open an issue (make sure to include the video ID)!"
    end

    # Raised when a request to YouTube fails
    class YouTubeRequestFailed < CouldNotRetrieveTranscript
      CAUSE_MESSAGE = "Request to YouTube failed: %<reason>s"

      # @return [String] the reason for the failure
      attr_reader :reason

      # @param video_id [String] the YouTube video ID
      # @param http_error [StandardError] the HTTP error that occurred
      def initialize(video_id, http_error)
        @reason = http_error.to_s
        super(video_id)
      end

      def cause_message
        format(CAUSE_MESSAGE, reason: @reason)
      end
    end

    # Raised when a video is unplayable
    class VideoUnplayable < CouldNotRetrieveTranscript
      CAUSE_MESSAGE = "The video is unplayable for the following reason: %<reason>s"

      # @return [String, nil] the reason the video is unplayable
      attr_reader :reason

      # @return [Array<String>] additional sub-reasons
      attr_reader :sub_reasons

      # @param video_id [String] the YouTube video ID
      # @param reason [String, nil] the reason the video is unplayable
      # @param sub_reasons [Array<String>] additional details
      def initialize(video_id, reason = nil, sub_reasons = [])
        @reason = reason
        @sub_reasons = sub_reasons
        super(video_id)
      end

      def cause_message
        reason_text = @reason || "No reason specified!"

        if @sub_reasons.any?
          sub_reasons_text = @sub_reasons.map { |r| " - #{r}" }.join("\n")
          reason_text = "#{reason_text}\n\nAdditional Details:\n#{sub_reasons_text}"
        end

        format(CAUSE_MESSAGE, reason: reason_text)
      end
    end

    # Raised when a video is unavailable
    class VideoUnavailable < CouldNotRetrieveTranscript
      CAUSE_MESSAGE = "The video is no longer available"
    end

    # Raised when an invalid video ID is provided
    class InvalidVideoId < CouldNotRetrieveTranscript
      CAUSE_MESSAGE = "You provided an invalid video id. Make sure you are using the video id and NOT the url!\n\n" \
                      'Do NOT run: `YoutubeRb::Transcript.fetch("https://www.youtube.com/watch?v=1234")`' \
                      "\n" \
                      'Instead run: `YoutubeRb::Transcript.fetch("1234")`'
    end

    # Raised when YouTube blocks the request
    class RequestBlocked < CouldNotRetrieveTranscript
      BASE_CAUSE_MESSAGE = "YouTube is blocking requests from your IP. This usually is due to one of the " \
                           "following reasons:\n" \
                           "- You have done too many requests and your IP has been blocked by YouTube\n" \
                           "- You are doing requests from an IP belonging to a cloud provider (like AWS, " \
                           "Google Cloud Platform, Azure, etc.). Unfortunately, most IPs from cloud " \
                           "providers are blocked by YouTube.\n\n"

      CAUSE_MESSAGE = "#{BASE_CAUSE_MESSAGE}" \
                      "There are two things you can do to work around this:\n" \
                      "1. Use proxies to hide your IP address.\n" \
                      "2. (NOT RECOMMENDED) If you authenticate your requests using cookies, you " \
                      "will be able to continue doing requests for a while. However, YouTube will " \
                      "eventually permanently ban the account that you have used to authenticate " \
                      "with! So only do this if you don't mind your account being banned!"
    end

    # Raised when YouTube blocks the IP specifically
    class IpBlocked < RequestBlocked
      CAUSE_MESSAGE = "#{RequestBlocked::BASE_CAUSE_MESSAGE}" \
                      "Ways to work around this are using proxies or rotating residential IPs."
    end

    # Raised when too many requests are made (HTTP 429)
    class TooManyRequests < CouldNotRetrieveTranscript
      CAUSE_MESSAGE = "YouTube is rate limiting your requests. Please wait before making more requests."
    end

    # Raised when transcripts are disabled for a video
    class TranscriptsDisabled < CouldNotRetrieveTranscript
      CAUSE_MESSAGE = "Subtitles are disabled for this video"
    end

    # Raised when a video is age restricted
    class AgeRestricted < CouldNotRetrieveTranscript
      CAUSE_MESSAGE = "This video is age-restricted. Therefore, you are unable to retrieve " \
                      "transcripts for it without authenticating yourself.\n\n" \
                      "Unfortunately, Cookie Authentication is temporarily unsupported, " \
                      "as recent changes in YouTube's API broke the previous implementation."
    end

    # Raised when a transcript is not translatable
    class NotTranslatable < CouldNotRetrieveTranscript
      CAUSE_MESSAGE = "The requested language is not translatable"
    end

    # Raised when the requested translation language is not available
    class TranslationLanguageNotAvailable < CouldNotRetrieveTranscript
      CAUSE_MESSAGE = "The requested translation language is not available"
    end

    # Raised when consent cookie creation fails
    class FailedToCreateConsentCookie < CouldNotRetrieveTranscript
      CAUSE_MESSAGE = "Failed to automatically give consent to saving cookies"
    end

    # Raised when no transcript is found for the requested languages
    class NoTranscriptFound < CouldNotRetrieveTranscript
      CAUSE_MESSAGE = "No transcripts were found for any of the requested language codes: %<requested_language_codes>s\n\n%<transcript_data>s"

      # @return [Array<String>] the requested language codes
      attr_reader :requested_language_codes

      # @return [Object] the transcript data (TranscriptList)
      attr_reader :transcript_data

      # @param video_id [String] the YouTube video ID
      # @param requested_language_codes [Array<String>] the language codes that were requested
      # @param transcript_data [Object] the TranscriptList object with available transcripts
      def initialize(video_id, requested_language_codes, transcript_data)
        @requested_language_codes = requested_language_codes
        @transcript_data = transcript_data
        super(video_id)
      end

      def cause_message
        format(
          CAUSE_MESSAGE,
          requested_language_codes: @requested_language_codes.inspect,
          transcript_data: @transcript_data.to_s
        )
      end
    end

    # Raised when no transcripts are available for a video
    class NoTranscriptAvailable < CouldNotRetrieveTranscript
      CAUSE_MESSAGE = "No transcripts are available for this video"
    end

    # Raised when a PO token is required to fetch the transcript
    class PoTokenRequired < CouldNotRetrieveTranscript
      CAUSE_MESSAGE = "The requested video cannot be retrieved without a PO Token. " \
                      "If this happens, please open a GitHub issue!"
    end
  end
end
