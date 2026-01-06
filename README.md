# YouTube Transcript Ruby

A Ruby library to retrieve transcripts and subtitles from YouTube videos. This is a port of the Python [youtube-transcript-api](https://github.com/jdepoix/youtube-transcript-api).

## ⚠️ Important Notice

**As of January 2026, YouTube has implemented PO (Proof of Origin) token requirements for transcript access.** This affects all transcript extraction libraries, including this one and the original Python library.

Currently, this library **does not support PO token authentication**, which means transcript fetching may fail with a `PoTokenRequired` error for many videos. This is a known limitation that affects the entire ecosystem of YouTube transcript tools.

**Status:** We are monitoring the situation and will implement PO token support when a viable solution becomes available. See [issue tracker](https://github.com/jdepoix/youtube-transcript-api/issues) for updates.

## Features

- Fetch transcripts/subtitles for any YouTube video
- Support for automatically generated and manually created captions
- Language preference selection
- Translation support for videos with translatable transcripts
- Multiple output formatters (JSON, WebVTT, SRT, plain text)
- HTML formatting preservation option
- No API key required

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'youtube-transcript-rb'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install youtube-transcript-rb
```

## Usage

### Basic Usage

Fetch a transcript for a video:

```ruby
require 'youtube/transcript/rb'

# Fetch transcript using convenience method
transcript = Youtube::Transcript::Rb.fetch('video_id')

# Iterate over transcript snippets
transcript.each do |snippet|
  puts snippet.text
  puts snippet.start  # Start time in seconds
  puts snippet.duration
end
```

### Using the API Class

```ruby
require 'youtube/transcript/rb'

api = Youtube::Transcript::Rb::YouTubeTranscriptApi.new

# Fetch a transcript
transcript = api.fetch('video_id', languages: ['en'])

# List all available transcripts
transcript_list = api.list('video_id')
puts transcript_list
```

### Language Selection

Specify preferred languages (the first available will be used):

```ruby
# Try Korean first, then English
transcript = Youtube::Transcript::Rb.fetch('video_id', languages: ['ko', 'en'])
```

### Working with TranscriptList

```ruby
transcript_list = Youtube::Transcript::Rb.list('video_id')

# Find a specific transcript by language
transcript = transcript_list.find_transcript(['en'])

# Get only manually created transcripts
transcript = transcript_list.find_manually_created_transcript(['en'])

# Get only auto-generated transcripts
transcript = transcript_list.find_generated_transcript(['en'])

# Fetch the transcript
fetched = transcript.fetch
```

### Translation

Translate transcripts to different languages:

```ruby
transcript_list = Youtube::Transcript::Rb.list('video_id')
transcript = transcript_list.find_transcript(['en'])

# Check if translatable
if transcript.translatable?
  # Translate to Spanish
  translated = transcript.translate('es')
  fetched = translated.fetch
end
```

### Formatting Options

Preserve HTML formatting in transcript text:

```ruby
transcript = Youtube::Transcript::Rb.fetch('video_id', preserve_formatting: true)
```

### Output Formatters

Convert transcripts to different formats:

```ruby
require 'youtube/transcript/rb'

transcript = Youtube::Transcript::Rb.fetch('video_id')

# Plain text
formatter = Youtube::Transcript::Rb::Formatters::TextFormatter.new
puts formatter.format(transcript)

# JSON
formatter = Youtube::Transcript::Rb::Formatters::JSONFormatter.new
puts formatter.format(transcript)

# WebVTT
formatter = Youtube::Transcript::Rb::Formatters::WebVTTFormatter.new
File.write('transcript.vtt', formatter.format(transcript))

# SRT (SubRip)
formatter = Youtube::Transcript::Rb::Formatters::SRTFormatter.new
File.write('transcript.srt', formatter.format(transcript))

# Pretty print with timestamps
formatter = Youtube::Transcript::Rb::Formatters::PrettyPrintFormatter.new
puts formatter.format(transcript)
```

### Error Handling

```ruby
begin
  transcript = Youtube::Transcript::Rb.fetch('video_id')
rescue Youtube::Transcript::Rb::PoTokenRequired => e
  puts "PO token required - this is a YouTube limitation as of 2026"
  puts e.message  # Contains detailed explanation
rescue Youtube::Transcript::Rb::TranscriptsDisabled => e
  puts "Transcripts are disabled for this video"
rescue Youtube::Transcript::Rb::NoTranscriptFound => e
  puts "No transcript found for requested languages"
rescue Youtube::Transcript::Rb::VideoUnavailable => e
  puts "Video is unavailable"
rescue Youtube::Transcript::Rb::TooManyRequests => e
  puts "Rate limited - please wait before retrying"
end
```

## Available Exceptions

- `Youtube::Transcript::Rb::Error` - Base error class
- `Youtube::Transcript::Rb::PoTokenRequired` - **PO token required (common as of 2026)**
- `Youtube::Transcript::Rb::TranscriptsDisabled` - Transcripts are disabled for the video
- `Youtube::Transcript::Rb::NoTranscriptFound` - No transcript found in requested languages
- `Youtube::Transcript::Rb::NoTranscriptAvailable` - No transcripts available for the video
- `Youtube::Transcript::Rb::VideoUnavailable` - Video is unavailable
- `Youtube::Transcript::Rb::TranslationLanguageNotAvailable` - Requested translation language not available
- `Youtube::Transcript::Rb::TooManyRequests` - Rate limited by YouTube

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bundle exec rspec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

## Testing

```bash
bundle exec rspec
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/jeff.dean/youtube-transcript-rb.

## License

This project is available as open source.

## Credits

This is a Ruby port of [youtube-transcript-api](https://github.com/jdepoix/youtube-transcript-api) by jdepoix.
