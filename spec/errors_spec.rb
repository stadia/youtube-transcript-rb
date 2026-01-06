# frozen_string_literal: true

require "spec_helper"
require "youtube/transcript/rb"

RSpec.describe Youtube::Transcript::Rb do
  describe "Error hierarchy" do
    it "has Error as the base class" do
      expect(Youtube::Transcript::Rb::Error).to be < StandardError
    end

    it "has CouldNotRetrieveTranscript inheriting from Error" do
      expect(Youtube::Transcript::Rb::CouldNotRetrieveTranscript).to be < Youtube::Transcript::Rb::Error
    end

    describe "error classes inherit from CouldNotRetrieveTranscript" do
      [
        Youtube::Transcript::Rb::YouTubeDataUnparsable,
        Youtube::Transcript::Rb::YouTubeRequestFailed,
        Youtube::Transcript::Rb::VideoUnplayable,
        Youtube::Transcript::Rb::VideoUnavailable,
        Youtube::Transcript::Rb::InvalidVideoId,
        Youtube::Transcript::Rb::RequestBlocked,
        Youtube::Transcript::Rb::IpBlocked,
        Youtube::Transcript::Rb::TooManyRequests,
        Youtube::Transcript::Rb::TranscriptsDisabled,
        Youtube::Transcript::Rb::AgeRestricted,
        Youtube::Transcript::Rb::NotTranslatable,
        Youtube::Transcript::Rb::TranslationLanguageNotAvailable,
        Youtube::Transcript::Rb::FailedToCreateConsentCookie,
        Youtube::Transcript::Rb::NoTranscriptFound,
        Youtube::Transcript::Rb::NoTranscriptAvailable,
        Youtube::Transcript::Rb::PoTokenRequired
      ].each do |error_class|
        it "#{error_class} inherits from CouldNotRetrieveTranscript" do
          expect(error_class).to be < Youtube::Transcript::Rb::CouldNotRetrieveTranscript
        end
      end
    end
  end

  describe Youtube::Transcript::Rb::CouldNotRetrieveTranscript do
    let(:video_id) { "test_video_123" }

    it "stores the video_id" do
      # Using a subclass since CouldNotRetrieveTranscript needs CAUSE_MESSAGE
      error = Youtube::Transcript::Rb::VideoUnavailable.new(video_id)
      expect(error.video_id).to eq(video_id)
    end

    it "includes video URL in error message" do
      error = Youtube::Transcript::Rb::VideoUnavailable.new(video_id)
      expect(error.message).to include("https://www.youtube.com/watch?v=#{video_id}")
    end

    it "includes cause message in error message" do
      error = Youtube::Transcript::Rb::VideoUnavailable.new(video_id)
      expect(error.message).to include("The video is no longer available")
    end
  end

  describe Youtube::Transcript::Rb::VideoUnavailable do
    let(:video_id) { "unavailable_video" }
    let(:error) { described_class.new(video_id) }

    it "has the correct cause message" do
      expect(error.cause_message).to eq("The video is no longer available")
    end
  end

  describe Youtube::Transcript::Rb::TranscriptsDisabled do
    let(:video_id) { "disabled_video" }
    let(:error) { described_class.new(video_id) }

    it "has the correct cause message" do
      expect(error.cause_message).to eq("Subtitles are disabled for this video")
    end
  end

  describe Youtube::Transcript::Rb::TooManyRequests do
    let(:video_id) { "rate_limited" }
    let(:error) { described_class.new(video_id) }

    it "has the correct cause message" do
      expect(error.cause_message).to include("rate limiting")
    end
  end

  describe Youtube::Transcript::Rb::PoTokenRequired do
    let(:video_id) { "po_token_video" }
    let(:error) { described_class.new(video_id) }

    it "has the correct cause message" do
      expect(error.cause_message).to include("PO Token")
    end
  end

  describe Youtube::Transcript::Rb::InvalidVideoId do
    let(:video_id) { "https://www.youtube.com/watch?v=1234" }
    let(:error) { described_class.new(video_id) }

    it "includes usage instructions in cause message" do
      expect(error.cause_message).to include("Do NOT run")
      expect(error.cause_message).to include("Instead run")
    end
  end

  describe Youtube::Transcript::Rb::YouTubeRequestFailed do
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

  describe Youtube::Transcript::Rb::VideoUnplayable do
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

  describe Youtube::Transcript::Rb::NoTranscriptFound do
    let(:video_id) { "no_transcript" }
    let(:requested_languages) { ["ko", "ja"] }
    let(:transcript_data) { double("TranscriptList", to_s: "Available: en, es") }
    let(:error) { described_class.new(video_id, requested_languages, transcript_data) }

    it "stores requested_language_codes" do
      expect(error.requested_language_codes).to eq(["ko", "ja"])
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

  describe Youtube::Transcript::Rb::RequestBlocked do
    let(:video_id) { "blocked_video" }
    let(:error) { described_class.new(video_id) }

    it "mentions IP blocking" do
      expect(error.cause_message).to include("YouTube is blocking requests from your IP")
    end

    it "mentions cloud providers" do
      expect(error.cause_message).to include("cloud provider")
    end
  end

  describe Youtube::Transcript::Rb::IpBlocked do
    let(:video_id) { "ip_blocked" }
    let(:error) { described_class.new(video_id) }

    it "inherits from RequestBlocked" do
      expect(described_class).to be < Youtube::Transcript::Rb::RequestBlocked
    end

    it "mentions IP or proxies as workaround" do
      expect(error.cause_message).to include("IP").or include("proxy")
    end
  end

  describe Youtube::Transcript::Rb::AgeRestricted do
    let(:video_id) { "age_restricted" }
    let(:error) { described_class.new(video_id) }

    it "mentions age restriction" do
      expect(error.cause_message).to include("age-restricted")
    end

    it "mentions authentication limitation" do
      expect(error.cause_message).to include("Cookie Authentication is temporarily unsupported")
    end
  end

  describe Youtube::Transcript::Rb::NotTranslatable do
    let(:video_id) { "not_translatable" }
    let(:error) { described_class.new(video_id) }

    it "has the correct cause message" do
      expect(error.cause_message).to include("not translatable")
    end
  end

  describe Youtube::Transcript::Rb::TranslationLanguageNotAvailable do
    let(:video_id) { "translation_unavailable" }
    let(:error) { described_class.new(video_id) }

    it "has the correct cause message" do
      expect(error.cause_message).to include("translation language is not available")
    end
  end
end
