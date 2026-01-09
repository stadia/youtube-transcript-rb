# frozen_string_literal: true

require "json"

module YoutubeRb
  # Module containing all transcript formatters
  module Formatters
    # Base formatter class. All formatters should inherit from this class
    # and implement their own format_transcript and format_transcripts methods.
    class Formatter
      # Format a single transcript
      #
      # @param transcript [FetchedTranscript] The transcript to format
      # @param options [Hash] Additional formatting options
      # @return [String] The formatted transcript
      def format_transcript(transcript, **options)
        raise NotImplementedError, "Subclass must implement #format_transcript"
      end

      # Format multiple transcripts
      #
      # @param transcripts [Array<FetchedTranscript>] The transcripts to format
      # @param options [Hash] Additional formatting options
      # @return [String] The formatted transcripts
      def format_transcripts(transcripts, **options)
        raise NotImplementedError, "Subclass must implement #format_transcripts"
      end
    end

    # Formats transcript as pretty-printed Ruby data structures
    class PrettyPrintFormatter < Formatter
      # Format a single transcript as pretty-printed output
      #
      # @param transcript [FetchedTranscript] The transcript to format
      # @param options [Hash] Options passed to PP.pp
      # @return [String] Pretty-printed transcript data
      def format_transcript(transcript, **options)
        require "pp"
        PP.pp(transcript.to_raw_data, +"", options[:width] || 79)
      end

      # Format multiple transcripts as pretty-printed output
      #
      # @param transcripts [Array<FetchedTranscript>] The transcripts to format
      # @param options [Hash] Options passed to PP.pp
      # @return [String] Pretty-printed transcripts data
      def format_transcripts(transcripts, **options)
        require "pp"
        data = transcripts.map(&:to_raw_data)
        PP.pp(data, +"", options[:width] || 79)
      end
    end

    # Formats transcript as JSON
    class JSONFormatter < Formatter
      # Format a single transcript as JSON
      #
      # @param transcript [FetchedTranscript] The transcript to format
      # @param options [Hash] Options passed to JSON.generate (e.g., :indent, :space)
      # @return [String] JSON representation of the transcript
      def format_transcript(transcript, **options)
        JSON.generate(transcript.to_raw_data, options)
      end

      # Format multiple transcripts as JSON array
      #
      # @param transcripts [Array<FetchedTranscript>] The transcripts to format
      # @param options [Hash] Options passed to JSON.generate
      # @return [String] JSON array representation of the transcripts
      def format_transcripts(transcripts, **options)
        data = transcripts.map(&:to_raw_data)
        JSON.generate(data, options)
      end
    end

    # Formats transcript as plain text (text only, no timestamps)
    class TextFormatter < Formatter
      # Format a single transcript as plain text
      #
      # @param transcript [FetchedTranscript] The transcript to format
      # @param options [Hash] Unused options
      # @return [String] Plain text with each line separated by newlines
      def format_transcript(transcript, **options)
        transcript.map(&:text).join("\n")
      end

      # Format multiple transcripts as plain text
      #
      # @param transcripts [Array<FetchedTranscript>] The transcripts to format
      # @param options [Hash] Unused options
      # @return [String] Plain text with transcripts separated by triple newlines
      def format_transcripts(transcripts, **options)
        transcripts.map { |t| format_transcript(t, **options) }.join("\n\n\n")
      end
    end

    # Base class for timestamp-based formatters (SRT, WebVTT)
    class TextBasedFormatter < TextFormatter
      # Format a single transcript with timestamps
      #
      # @param transcript [FetchedTranscript] The transcript to format
      # @param options [Hash] Unused options
      # @return [String] Formatted transcript with timestamps
      def format_transcript(transcript, **options)
        lines = []
        snippets = transcript.to_a

        snippets.each_with_index do |snippet, i|
          end_time = snippet.start + snippet.duration

          # Use next snippet's start time if it starts before current end time
          end_time = snippets[i + 1].start if i < snippets.length - 1 && snippets[i + 1].start < end_time

          time_text = "#{seconds_to_timestamp(snippet.start)} --> #{seconds_to_timestamp(end_time)}"
          lines << format_transcript_helper(i, time_text, snippet)
        end

        format_transcript_header(lines)
      end

      protected

      # Format a timestamp from components
      #
      # @param hours [Integer] Hours component
      # @param mins [Integer] Minutes component
      # @param secs [Integer] Seconds component
      # @param ms [Integer] Milliseconds component
      # @return [String] Formatted timestamp
      def format_timestamp(hours, mins, secs, ms)
        raise NotImplementedError, "Subclass must implement #format_timestamp"
      end

      # Format the transcript header/wrapper
      #
      # @param lines [Array<String>] The formatted lines
      # @return [String] The complete formatted transcript
      def format_transcript_header(lines)
        raise NotImplementedError, "Subclass must implement #format_transcript_header"
      end

      # Format a single transcript entry
      #
      # @param index [Integer] The entry index (0-based)
      # @param time_text [String] The formatted time range
      # @param snippet [TranscriptSnippet] The snippet to format
      # @return [String] The formatted entry
      def format_transcript_helper(index, time_text, snippet)
        raise NotImplementedError, "Subclass must implement #format_transcript_helper"
      end

      private

      # Convert seconds to timestamp string
      #
      # @param time [Float] Time in seconds
      # @return [String] Formatted timestamp
      def seconds_to_timestamp(time)
        time = time.to_f
        hours, remainder = time.divmod(3600)
        mins, secs_float = remainder.divmod(60)
        secs = secs_float.to_i
        ms = ((time - time.to_i) * 1000).round

        format_timestamp(hours.to_i, mins.to_i, secs, ms)
      end
    end

    # Formats transcript as SRT (SubRip) subtitle format
    #
    # @example SRT format
    #   1
    #   00:00:00,000 --> 00:00:02,500
    #   Hello world
    #
    #   2
    #   00:00:02,500 --> 00:00:05,000
    #   This is a test
    #
    class SRTFormatter < TextBasedFormatter
      protected

      def format_timestamp(hours, mins, secs, ms)
        format("%02d:%02d:%02d,%03d", hours, mins, secs, ms)
      end

      def format_transcript_header(lines)
        "#{lines.join("\n\n")}\n"
      end

      def format_transcript_helper(index, time_text, snippet)
        "#{index + 1}\n#{time_text}\n#{snippet.text}"
      end
    end

    # Formats transcript as WebVTT (Web Video Text Tracks) format
    #
    # @example WebVTT format
    #   WEBVTT
    #
    #   00:00:00.000 --> 00:00:02.500
    #   Hello world
    #
    #   00:00:02.500 --> 00:00:05.000
    #   This is a test
    #
    class WebVTTFormatter < TextBasedFormatter
      protected

      def format_timestamp(hours, mins, secs, ms)
        format("%02d:%02d:%02d.%03d", hours, mins, secs, ms)
      end

      def format_transcript_header(lines)
        "WEBVTT\n\n#{lines.join("\n\n")}\n"
      end

      def format_transcript_helper(index, time_text, snippet)
        "#{time_text}\n#{snippet.text}"
      end
    end

    # Utility class to load formatters by type name
    class FormatterLoader
      # Mapping of format names to formatter classes
      TYPES = {
        "json" => JSONFormatter,
        "pretty" => PrettyPrintFormatter,
        "text" => TextFormatter,
        "webvtt" => WebVTTFormatter,
        "srt" => SRTFormatter
      }.freeze

      # Error raised when an unknown formatter type is requested
      class UnknownFormatterType < StandardError
        def initialize(formatter_type)
          super(
            "The format '#{formatter_type}' is not supported. " \
            "Choose one of the following formats: #{TYPES.keys.join(', ')}"
          )
        end
      end

      # Load a formatter by type name
      #
      # @param formatter_type [String] The formatter type (json, pretty, text, webvtt, srt)
      # @return [Formatter] An instance of the requested formatter
      # @raise [UnknownFormatterType] If the formatter type is not supported
      #
      # @example
      #   loader = FormatterLoader.new
      #   formatter = loader.load("json")
      #   output = formatter.format_transcript(transcript)
      #
      def load(formatter_type = "pretty")
        formatter_type = formatter_type.to_s
        raise UnknownFormatterType, formatter_type unless TYPES.key?(formatter_type)

        TYPES[formatter_type].new
      end
    end
  end
end
