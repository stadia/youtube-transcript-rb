# frozen_string_literal: true

require "spec_helper"
require "youtube_rb/transcript"

RSpec.describe YoutubeRb::Transcript do
  describe "Error hierarchy" do
    it "has Error as the base class" do
      expect(YoutubeRb::Transcript::Error).to be < StandardError
    end

    it "has CouldNotRetrieveTranscript inheriting from Error" do
      expect(YoutubeRb::Transcript::CouldNotRetrieveTranscript).to be < YoutubeRb::Transcript::Error
    end

    describe "error classes inherit from CouldNotRetrieveTranscript" do
      [
        YoutubeRb::Transcript::YouTubeDataUnparsable,
        YoutubeRb::Transcript::YouTubeRequestFailed,
        YoutubeRb::Transcript::VideoUnplayable,
        YoutubeRb::Transcript::VideoUnavailable,
        YoutubeRb::Transcript::InvalidVideoId,
        YoutubeRb::Transcript::RequestBlocked,
        YoutubeRb::Transcript::IpBlocked,
        YoutubeRb::Transcript::TooManyRequests,
        YoutubeRb::Transcript::TranscriptsDisabled,
        YoutubeRb::Transcript::AgeRestricted,
        YoutubeRb::Transcript::NotTranslatable,
        YoutubeRb::Transcript::TranslationLanguageNotAvailable,
        YoutubeRb::Transcript::FailedToCreateConsentCookie,
        YoutubeRb::Transcript::NoTranscriptFound,
        YoutubeRb::Transcript::NoTranscriptAvailable,
        YoutubeRb::Transcript::PoTokenRequired
      ].each do |error_class|
        it "#{error_class} inherits from CouldNotRetrieveTranscript" do
          expect(error_class).to be < YoutubeRb::Transcript::CouldNotRetrieveTranscript
        end
      end
    end
  end

  describe YoutubeRb::Transcript::CouldNotRetrieveTranscript do
    let(:video_id) { "test_video_123" }

    it "stores the video_id" do
      # Using a subclass since CouldNotRetrieveTranscript needs CAUSE_MESSAGE
      error = YoutubeRb::Transcript::VideoUnavailable.new(video_id)
      expect(error.video_id).to eq(video_id)
    end

    it "includes video URL in error message" do
      error = YoutubeRb::Transcript::VideoUnavailable.new(video_id)
      expect(error.message).to include("https://www.youtube.com/watch?v=#{video_id}")
    end

    it "includes cause message in error message" do
      error = YoutubeRb::Transcript::VideoUnavailable.new(video_id)
      expect(error.message).to include("The video is no longer available")
    end
  end

  describe YoutubeRb::Transcript::VideoUnavailable do
    let(:video_id) { "unavailable_video" }
    let(:error) { described_class.new(video_id) }

    it "has the correct cause message" do
      expect(error.cause_message).to eq("The video is no longer available")
    end
  end

  describe YoutubeRb::Transcript::TranscriptsDisabled do
    let(:video_id) { "disabled_video" }
    let(:error) { described_class.new(video_id) }

    it "has the correct cause message" do
      expect(error.cause_message).to eq("Subtitles are disabled for this video")
    end
  end

  describe YoutubeRb::Transcript::TooManyRequests do
    let(:video_id) { "rate_limited" }
    let(:error) { described_class.new(video_id) }

    it "has the correct cause message" do
      expect(error.cause_message).to include("rate limiting")
    end
  end

  describe YoutubeRb::Transcript::PoTokenRequired do
    let(:video_id) { "po_token_video" }
    let(:error) { described_class.new(video_id) }

    it "has the correct cause message" do
      expect(error.cause_message).to include("PO Token")
    end
  end

  describe YoutubeRb::Transcript::InvalidVideoId do
    let(:video_id) { "https://www.youtube.com/watch?v=1234" }
    let(:error) { described_class.new(video_id) }

    it "includes usage instructions in cause message" do
      expect(error.cause_message).to include("Do NOT run")
      expect(error.cause_message).to include("Instead run")
    end
  end

  describe YoutubeRb::Transcript::YouTubeRequestFailed do
    let(:video_id) { "failed_request" }
    let(:http_error) { StandardError.new("Connection refused") }
    let(:error) { described_class.new(video_id, http_error) }

    it "stores the reason" do
      expect(error.reason).to eq("Connection refused")
    end

    it "includes the reason in cause message" do
      expect(error.cause_message).to include("Connection refused")
    end
  end

  describe YoutubeRb::Transcript::VideoUnplayable do
    let(:video_id) { "unplayable_video" }

    context "with reason only" do
      let(:error) { described_class.new(video_id, "Video is private") }

      it "stores the reason" do
        expect(error.reason).to eq("Video is private")
      end

      it "includes reason in cause message" do
        expect(error.cause_message).to include("Video is private")
      end
    end

    context "with no reason" do
      let(:error) { described_class.new(video_id) }

      it "uses default reason text" do
        expect(error.cause_message).to include("No reason specified!")
      end
    end

    context "with sub_reasons" do
      let(:error) { described_class.new(video_id, "Video is restricted", ["Region blocked", "Age restricted"]) }

      it "stores sub_reasons" do
        expect(error.sub_reasons).to eq(["Region blocked", "Age restricted"])
      end

      it "includes sub_reasons in cause message" do
        expect(error.cause_message).to include("Region blocked")
        expect(error.cause_message).to include("Age restricted")
        expect(error.cause_message).to include("Additional Details")
      end
    end
  end

  describe YoutubeRb::Transcript::NoTranscriptFound do
    let(:video_id) { "no_transcript" }
    let(:requested_languages) { %w[ko ja] }
    let(:transcript_data) { double("TranscriptList", to_s: "Available: en, es") }
    let(:error) { described_class.new(video_id, requested_languages, transcript_data) }

    it "stores requested_language_codes" do
      expect(error.requested_language_codes).to eq(%w[ko ja])
    end

    it "stores transcript_data" do
      expect(error.transcript_data).to eq(transcript_data)
    end

    it "includes requested languages in cause message" do
      expect(error.cause_message).to include("ko")
      expect(error.cause_message).to include("ja")
    end

    it "includes transcript data in cause message" do
      expect(error.cause_message).to include("Available: en, es")
    end
  end

  describe YoutubeRb::Transcript::RequestBlocked do
    let(:video_id) { "blocked_video" }
    let(:error) { described_class.new(video_id) }

    it "mentions IP blocking" do
      expect(error.cause_message).to include("YouTube is blocking requests from your IP")
    end

    it "mentions cloud providers" do
      expect(error.cause_message).to include("cloud provider")
    end
  end

  describe YoutubeRb::Transcript::IpBlocked do
    let(:video_id) { "ip_blocked" }
    let(:error) { described_class.new(video_id) }

    it "inherits from RequestBlocked" do
      expect(described_class).to be < YoutubeRb::Transcript::RequestBlocked
    end

    it "mentions IP or proxies as workaround" do
      expect(error.cause_message).to include("IP").or include("proxy")
    end
  end

  describe YoutubeRb::Transcript::AgeRestricted do
    let(:video_id) { "age_restricted" }
    let(:error) { described_class.new(video_id) }

    it "mentions age restriction" do
      expect(error.cause_message).to include("age-restricted")
    end

    it "mentions authentication limitation" do
      expect(error.cause_message).to include("Cookie Authentication is temporarily unsupported")
    end
  end

  describe YoutubeRb::Transcript::NotTranslatable do
    let(:video_id) { "not_translatable" }
    let(:error) { described_class.new(video_id) }

    it "has the correct cause message" do
      expect(error.cause_message).to include("not translatable")
    end
  end

  describe YoutubeRb::Transcript::TranslationLanguageNotAvailable do
    let(:video_id) { "translation_unavailable" }
    let(:error) { described_class.new(video_id) }

    it "has the correct cause message" do
      expect(error.cause_message).to include("translation language is not available")
    end
  end
end
