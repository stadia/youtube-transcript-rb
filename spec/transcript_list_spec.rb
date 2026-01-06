# frozen_string_literal: true

require "spec_helper"

RSpec.describe Youtube::Transcript::Rb::TranscriptList do
  let(:http_client) { instance_double(Faraday::Connection) }
  let(:video_id) { "test_video_123" }

  # Sample captions JSON similar to what YouTube returns
  let(:sample_captions_json) do
    {
      "captionTracks" => [
        {
          "baseUrl" => "https://www.youtube.com/api/timedtext?v=test&lang=en&fmt=srv3",
          "name" => { "runs" => [{ "text" => "English" }] },
          "languageCode" => "en",
          "kind" => "",
          "isTranslatable" => true
        },
        {
          "baseUrl" => "https://www.youtube.com/api/timedtext?v=test&lang=es&fmt=srv3",
          "name" => { "runs" => [{ "text" => "Spanish" }] },
          "languageCode" => "es",
          "kind" => "",
          "isTranslatable" => false
        },
        {
          "baseUrl" => "https://www.youtube.com/api/timedtext?v=test&lang=en&fmt=srv3",
          "name" => { "runs" => [{ "text" => "English (auto-generated)" }] },
          "languageCode" => "en-auto",
          "kind" => "asr",
          "isTranslatable" => true
        }
      ],
      "translationLanguages" => [
        { "languageCode" => "fr", "languageName" => { "runs" => [{ "text" => "French" }] } },
        { "languageCode" => "de", "languageName" => { "runs" => [{ "text" => "German" }] } }
      ]
    }
  end

  describe ".build" do
    it "creates a TranscriptList from captions JSON" do
      list = described_class.build(
        http_client: http_client,
        video_id: video_id,
        captions_json: sample_captions_json
      )

      expect(list).to be_a(described_class)
      expect(list.video_id).to eq(video_id)
    end

    it "separates manually created and generated transcripts" do
      list = described_class.build(
        http_client: http_client,
        video_id: video_id,
        captions_json: sample_captions_json
      )

      # Should have 3 total transcripts (2 manual + 1 generated)
      expect(list.count).to eq(3)
    end

    it "removes &fmt=srv3 from base URLs" do
      list = described_class.build(
        http_client: http_client,
        video_id: video_id,
        captions_json: sample_captions_json
      )

      list.each do |transcript|
        # The URL should not contain &fmt=srv3
        expect(transcript.instance_variable_get(:@url)).not_to include("&fmt=srv3")
      end
    end

    it "handles empty captions JSON" do
      empty_json = { "captionTracks" => [], "translationLanguages" => [] }
      list = described_class.build(
        http_client: http_client,
        video_id: video_id,
        captions_json: empty_json
      )

      expect(list.count).to eq(0)
    end

    it "handles missing translationLanguages" do
      json = { "captionTracks" => sample_captions_json["captionTracks"] }
      list = described_class.build(
        http_client: http_client,
        video_id: video_id,
        captions_json: json
      )

      expect(list.count).to eq(3)
    end

    it "assigns translation languages only to translatable transcripts" do
      list = described_class.build(
        http_client: http_client,
        video_id: video_id,
        captions_json: sample_captions_json
      )

      transcripts = list.to_a
      en_transcript = transcripts.find { |t| t.language_code == "en" }
      es_transcript = transcripts.find { |t| t.language_code == "es" }

      expect(en_transcript.translation_languages).not_to be_empty
      expect(es_transcript.translation_languages).to be_empty
    end
  end

  describe "#initialize" do
    it "stores the video ID" do
      list = described_class.new(
        video_id: video_id,
        manually_created_transcripts: {},
        generated_transcripts: {},
        translation_languages: []
      )

      expect(list.video_id).to eq(video_id)
    end
  end

  describe "Enumerable" do
    let(:list) do
      described_class.build(
        http_client: http_client,
        video_id: video_id,
        captions_json: sample_captions_json
      )
    end

    it "includes Enumerable" do
      expect(described_class).to include(Enumerable)
    end

    describe "#each" do
      it "yields each transcript" do
        transcripts = []
        list.each { |t| transcripts << t }
        expect(transcripts.length).to eq(3)
      end

      it "returns an enumerator when no block given" do
        expect(list.each).to be_a(Enumerator)
      end

      it "yields manually created transcripts first" do
        transcripts = list.to_a
        # First two should be manually created (en and es)
        expect(transcripts[0].is_generated).to be false
        expect(transcripts[1].is_generated).to be false
        # Last one should be generated (en-auto)
        expect(transcripts[2].is_generated).to be true
      end
    end

    it "supports #map" do
      codes = list.map(&:language_code)
      expect(codes).to contain_exactly("en", "es", "en-auto")
    end

    it "supports #count" do
      expect(list.count).to eq(3)
    end

    it "supports #select" do
      generated = list.select(&:is_generated)
      expect(generated.length).to eq(1)
    end
  end

  describe "#find_transcript" do
    let(:list) do
      described_class.build(
        http_client: http_client,
        video_id: video_id,
        captions_json: sample_captions_json
      )
    end

    it "finds a transcript by language code" do
      transcript = list.find_transcript(["en"])
      expect(transcript.language_code).to eq("en")
      expect(transcript.language).to eq("English")
    end

    it "prefers manually created over generated transcripts" do
      transcript = list.find_transcript(["en"])
      expect(transcript.is_generated).to be false
    end

    it "tries language codes in order of priority" do
      transcript = list.find_transcript(["ja", "es", "en"])
      expect(transcript.language_code).to eq("es")
    end

    it "raises NoTranscriptFound when no match" do
      expect {
        list.find_transcript(["ja", "ko", "zh"])
      }.to raise_error(Youtube::Transcript::Rb::NoTranscriptFound)
    end

    it "includes requested languages in error" do
      begin
        list.find_transcript(["ja", "ko"])
      rescue Youtube::Transcript::Rb::NoTranscriptFound => e
        expect(e.requested_language_codes).to eq(["ja", "ko"])
      end
    end
  end

  describe "#find_generated_transcript" do
    let(:list) do
      described_class.build(
        http_client: http_client,
        video_id: video_id,
        captions_json: sample_captions_json
      )
    end

    it "finds only generated transcripts" do
      transcript = list.find_generated_transcript(["en-auto"])
      expect(transcript.language_code).to eq("en-auto")
      expect(transcript.is_generated).to be true
    end

    it "does not return manually created transcripts" do
      expect {
        list.find_generated_transcript(["en"])
      }.to raise_error(Youtube::Transcript::Rb::NoTranscriptFound)
    end

    it "raises NoTranscriptFound when no match" do
      expect {
        list.find_generated_transcript(["ja"])
      }.to raise_error(Youtube::Transcript::Rb::NoTranscriptFound)
    end
  end

  describe "#find_manually_created_transcript" do
    let(:list) do
      described_class.build(
        http_client: http_client,
        video_id: video_id,
        captions_json: sample_captions_json
      )
    end

    it "finds only manually created transcripts" do
      transcript = list.find_manually_created_transcript(["en"])
      expect(transcript.language_code).to eq("en")
      expect(transcript.is_generated).to be false
    end

    it "does not return generated transcripts" do
      expect {
        list.find_manually_created_transcript(["en-auto"])
      }.to raise_error(Youtube::Transcript::Rb::NoTranscriptFound)
    end

    it "tries language codes in order" do
      transcript = list.find_manually_created_transcript(["ja", "es"])
      expect(transcript.language_code).to eq("es")
    end
  end

  describe "#to_s" do
    let(:list) do
      described_class.build(
        http_client: http_client,
        video_id: video_id,
        captions_json: sample_captions_json
      )
    end

    it "includes the video ID" do
      expect(list.to_s).to include(video_id)
    end

    it "includes MANUALLY CREATED section" do
      expect(list.to_s).to include("(MANUALLY CREATED)")
    end

    it "includes GENERATED section" do
      expect(list.to_s).to include("(GENERATED)")
    end

    it "includes TRANSLATION LANGUAGES section" do
      expect(list.to_s).to include("(TRANSLATION LANGUAGES)")
    end

    it "lists manually created transcripts" do
      str = list.to_s
      expect(str).to include("en")
      expect(str).to include("English")
    end

    it "lists translation languages" do
      str = list.to_s
      expect(str).to include("fr")
      expect(str).to include("French")
    end

    context "with empty transcript list" do
      let(:empty_list) do
        described_class.new(
          video_id: video_id,
          manually_created_transcripts: {},
          generated_transcripts: {},
          translation_languages: []
        )
      end

      it "shows None for empty sections" do
        str = empty_list.to_s
        expect(str).to include("None")
      end
    end
  end

  describe "edge cases" do
    it "handles missing name in caption tracks" do
      json = {
        "captionTracks" => [
          {
            "baseUrl" => "https://example.com",
            "name" => {},
            "languageCode" => "en"
          }
        ]
      }

      list = described_class.build(
        http_client: http_client,
        video_id: video_id,
        captions_json: json
      )

      expect(list.count).to eq(1)
    end

    it "handles nil baseUrl" do
      json = {
        "captionTracks" => [
          {
            "baseUrl" => nil,
            "name" => { "runs" => [{ "text" => "English" }] },
            "languageCode" => "en"
          }
        ]
      }

      list = described_class.build(
        http_client: http_client,
        video_id: video_id,
        captions_json: json
      )

      expect(list.count).to eq(1)
    end

    it "handles missing captionTracks" do
      json = { "translationLanguages" => [] }

      list = described_class.build(
        http_client: http_client,
        video_id: video_id,
        captions_json: json
      )

      expect(list.count).to eq(0)
    end
  end
end
