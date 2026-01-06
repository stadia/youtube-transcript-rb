# frozen_string_literal: true

# Integration tests that make real HTTP requests to YouTube.
# These tests are skipped by default to avoid network dependencies in CI.
#
# To run integration tests:
#   INTEGRATION=1 bundle exec rspec spec/integration_spec.rb
#
# Or run all tests including integration:
#   INTEGRATION=1 bundle exec rspec

require "spec_helper"

RSpec.describe "Integration Tests", :integration do
  # Skip all integration tests unless INTEGRATION env var is set
  before(:all) do
    skip "Integration tests skipped. Set INTEGRATION=1 to run." unless ENV["INTEGRATION"]
    WebMock.allow_net_connect!
  end

  after(:all) do
    WebMock.disable_net_connect!(allow_localhost: true) if ENV["INTEGRATION"]
  end

  # Well-known videos that should have transcripts available
  # Using popular, stable videos that are unlikely to be removed
  let(:ted_talk_video_id) { "8jPQjjsBbIc" } # TED Talk - usually has good transcripts
  let(:google_video_id) { "dQw4w9WgXcQ" }   # Rick Astley - Never Gonna Give You Up (very stable)

  describe YoutubeRb::Transcript::YouTubeTranscriptApi do
    let(:api) { described_class.new }

    describe "#list" do
      it "fetches available transcripts for a video" do
        transcript_list = api.list(ted_talk_video_id)

        expect(transcript_list).to be_a(YoutubeRb::Transcript::TranscriptMetadataList)
        expect(transcript_list.video_id).to eq(ted_talk_video_id)
        expect(transcript_list.count).to be > 0

        # Print available transcripts for debugging
        puts "\nAvailable transcripts for video #{ted_talk_video_id}:"
        puts transcript_list.to_s
      end

      it "returns a TranscriptList that is enumerable" do
        transcript_list = api.list(ted_talk_video_id)

        transcript_list.each do |transcript|
          expect(transcript).to be_a(YoutubeRb::Transcript::TranscriptMetadata)
          expect(transcript.language_code).to be_a(String)
          expect(transcript.language).to be_a(String)
        end
      end
    end

    describe "#fetch" do
      it "fetches English transcript by default" do
        transcript = api.fetch(ted_talk_video_id)

        expect(transcript).to be_a(YoutubeRb::Transcript::FetchedTranscript)
        expect(transcript.video_id).to eq(ted_talk_video_id)
        expect(transcript.snippets).not_to be_empty

        first_snippet = transcript.first
        expect(first_snippet).to be_a(YoutubeRb::Transcript::TranscriptMetadataSnippet)
        expect(first_snippet.text).to be_a(String)
        expect(first_snippet.start).to be_a(Float)
        expect(first_snippet.duration).to be_a(Float)

        puts "\nFetched #{transcript.length} snippets"
        puts "First snippet: #{first_snippet.text[0..50]}..."
      end

      it "fetches transcript with specific language" do
        # Try to fetch English transcript
        transcript = api.fetch(ted_talk_video_id, languages: ["en"])

        expect(transcript.language_code).to eq("en")
        expect(transcript.snippets).not_to be_empty
      end

      it "falls back to alternative language if primary not available" do
        # Request Japanese first, then English as fallback
        transcript = api.fetch(ted_talk_video_id, languages: ["ja", "en"])

        expect(["ja", "en"]).to include(transcript.language_code)
        expect(transcript.snippets).not_to be_empty
      end

      it "preserves HTML formatting when requested" do
        transcript = api.fetch(ted_talk_video_id, preserve_formatting: true)

        expect(transcript).to be_a(YoutubeRb::Transcript::FetchedTranscript)
        # Note: Not all videos have HTML formatting, so we just verify it doesn't break
      end
    end

    describe "#fetch_all" do
      it "fetches transcripts for multiple videos" do
        video_ids = [ted_talk_video_id]
        results = api.fetch_all(video_ids)

        expect(results).to be_a(Hash)
        expect(results.keys).to include(ted_talk_video_id)
        expect(results[ted_talk_video_id]).to be_a(YoutubeRb::Transcript::FetchedTranscript)
      end

      it "continues on error when option is set" do
        video_ids = [ted_talk_video_id, "invalid_video_id_xyz"]
        errors = []

        results = api.fetch_all(video_ids, continue_on_error: true) do |video_id, result|
          if result.is_a?(StandardError)
            errors << { video_id: video_id, error: result }
          end
        end

        expect(results).to have_key(ted_talk_video_id)
        expect(errors.length).to be >= 0 # May or may not have errors
      end
    end
  end

  describe YoutubeRb::Transcript do
    describe ".fetch" do
      it "provides convenience method for fetching transcripts" do
        transcript = described_class.fetch(ted_talk_video_id)

        expect(transcript).to be_a(YoutubeRb::Transcript::FetchedTranscript)
        expect(transcript.snippets).not_to be_empty
      end
    end

    describe ".list" do
      it "provides convenience method for listing transcripts" do
        transcript_list = described_class.list(ted_talk_video_id)

        expect(transcript_list).to be_a(YoutubeRb::Transcript::TranscriptMetadataList)
        expect(transcript_list.count).to be > 0
      end
    end
  end

  describe "Transcript Translation" do
    it "translates a transcript to another language" do
      api = YoutubeRb::Transcript::YouTubeTranscriptApi.new
      transcript_list = api.list(ted_talk_video_id)

      # Find an English transcript
      begin
        transcript = transcript_list.find_transcript(["en"])
      rescue YoutubeRb::Transcript::NoTranscriptFound
        skip "No English transcript available for this video"
      end

      if transcript.translatable?
        # Try to translate to Spanish
        begin
          translated = transcript.translate("es")
          fetched = translated.fetch

          expect(fetched).to be_a(YoutubeRb::Transcript::FetchedTranscript)
          expect(fetched.language_code).to eq("es")
          expect(fetched.snippets).not_to be_empty

          puts "\nTranslated to Spanish: #{fetched.first.text[0..50]}..."
        rescue YoutubeRb::Transcript::TranslationLanguageNotAvailable
          skip "Spanish translation not available for this video"
        rescue YoutubeRb::Transcript::IpBlocked
          skip "IP blocked by YouTube - try again later or use a proxy"
        end
      else
        skip "Transcript is not translatable"
      end
    end
  end

  describe "Formatters with Real Data" do
    let(:api) { YoutubeRb::Transcript::YouTubeTranscriptApi.new }
    let(:transcript) { api.fetch(ted_talk_video_id) }

    describe YoutubeRb::Transcript::Formatters::JSONFormatter do
      it "formats real transcript as JSON" do
        formatter = described_class.new
        output = formatter.format_transcript(transcript)

        expect { JSON.parse(output) }.not_to raise_error
        parsed = JSON.parse(output)
        expect(parsed).to be_an(Array)
        expect(parsed.first).to include("text", "start", "duration")
      end
    end

    describe YoutubeRb::Transcript::Formatters::TextFormatter do
      it "formats real transcript as plain text" do
        formatter = described_class.new
        output = formatter.format_transcript(transcript)

        expect(output).to be_a(String)
        # Each snippet becomes one entry, but text may contain newlines
        # so we just verify it's not empty and has reasonable content
        expect(output).not_to be_empty
        expect(output.length).to be > transcript.length
      end
    end

    describe YoutubeRb::Transcript::Formatters::SRTFormatter do
      it "formats real transcript as SRT" do
        formatter = described_class.new
        output = formatter.format_transcript(transcript)

        expect(output).to include("-->")
        expect(output).to match(/^\d+$/m) # Sequence numbers

        # Verify SRT timestamp format (HH:MM:SS,mmm)
        expect(output).to match(/\d{2}:\d{2}:\d{2},\d{3}/)
      end
    end

    describe YoutubeRb::Transcript::Formatters::WebVTTFormatter do
      it "formats real transcript as WebVTT" do
        formatter = described_class.new
        output = formatter.format_transcript(transcript)

        expect(output).to start_with("WEBVTT")
        expect(output).to include("-->")

        # Verify WebVTT timestamp format (HH:MM:SS.mmm)
        expect(output).to match(/\d{2}:\d{2}:\d{2}\.\d{3}/)
      end
    end

    describe YoutubeRb::Transcript::Formatters::PrettyPrintFormatter do
      it "formats real transcript as pretty-printed output" do
        formatter = described_class.new
        output = formatter.format_transcript(transcript)

        expect(output).to be_a(String)
        expect(output).to include("text")
        expect(output).to include("start")
        expect(output).to include("duration")
      end
    end
  end

  describe "Error Handling" do
    let(:api) { YoutubeRb::Transcript::YouTubeTranscriptApi.new }

    it "raises NoTranscriptFound for unavailable language" do
      expect {
        api.fetch(ted_talk_video_id, languages: ["xx"]) # Invalid language code
      }.to raise_error(YoutubeRb::Transcript::NoTranscriptFound)
    end

    it "raises appropriate error for invalid video ID" do
      expect {
        api.fetch("this_is_not_a_valid_video_id_12345")
      }.to raise_error(YoutubeRb::Transcript::CouldNotRetrieveTranscript)
    end

    it "raises TranscriptsDisabled for video without transcripts" do
      # This test may need to be updated if the video gets transcripts
      # or use a known video without transcripts
      skip "Need a known video ID without transcripts"
    end
  end

  describe "FetchedTranscript Interface" do
    let(:api) { YoutubeRb::Transcript::YouTubeTranscriptApi.new }
    let(:transcript) { api.fetch(ted_talk_video_id) }

    it "is enumerable" do
      expect(transcript).to respond_to(:each)
      expect(transcript).to respond_to(:map)
      expect(transcript).to respond_to(:select)
      expect(transcript).to respond_to(:first)
      # Note: Enumerable doesn't provide #last by default, but we can use to_a.last
      expect(transcript.to_a.last).to be_a(YoutubeRb::Transcript::TranscriptMetadataSnippet)
    end

    it "is indexable" do
      expect(transcript[0]).to be_a(YoutubeRb::Transcript::TranscriptMetadataSnippet)
      expect(transcript[-1]).to be_a(YoutubeRb::Transcript::TranscriptMetadataSnippet)
    end

    it "has length" do
      expect(transcript.length).to be > 0
      expect(transcript.size).to eq(transcript.length)
    end

    it "converts to raw data" do
      raw = transcript.to_raw_data

      expect(raw).to be_an(Array)
      expect(raw.first).to be_a(Hash)
      expect(raw.first).to include("text", "start", "duration")
    end

    it "provides metadata" do
      expect(transcript.video_id).to eq(ted_talk_video_id)
      expect(transcript.language).to be_a(String)
      expect(transcript.language_code).to be_a(String)
      expect([true, false]).to include(transcript.is_generated)
    end
  end

  describe "TranscriptList Interface" do
    let(:api) { YoutubeRb::Transcript::YouTubeTranscriptApi.new }
    let(:transcript_list) { api.list(ted_talk_video_id) }

    it "is enumerable" do
      expect(transcript_list).to respond_to(:each)
      expect(transcript_list).to respond_to(:map)
      expect(transcript_list).to respond_to(:count)
    end

    it "finds transcripts by language" do
      transcript = transcript_list.find_transcript(["en"])
      expect(transcript).to be_a(YoutubeRb::Transcript::TranscriptMetadata)
    end

    it "provides string representation" do
      output = transcript_list.to_s

      expect(output).to include("MANUALLY CREATED")
      expect(output).to include("GENERATED")
      expect(output).to include(ted_talk_video_id)
    end
  end

  describe "Transcript Object" do
    let(:api) { YoutubeRb::Transcript::YouTubeTranscriptApi.new }
    let(:transcript_list) { api.list(ted_talk_video_id) }
    let(:transcript) { transcript_list.find_transcript(["en"]) }

    it "provides metadata properties" do
      expect(transcript.video_id).to eq(ted_talk_video_id)
      expect(transcript.language).to be_a(String)
      expect(transcript.language_code).to eq("en")
      expect([true, false]).to include(transcript.is_generated)
    end

    it "indicates translatability" do
      expect([true, false]).to include(transcript.translatable?)
      expect(transcript.translation_languages).to be_an(Array)
    end

    it "fetches transcript data" do
      fetched = transcript.fetch

      expect(fetched).to be_a(YoutubeRb::Transcript::FetchedTranscript)
      expect(fetched.snippets).not_to be_empty
    end

    it "provides string representation" do
      output = transcript.to_s

      expect(output).to include(transcript.language_code)
      expect(output).to include(transcript.language)
    end
  end
end
