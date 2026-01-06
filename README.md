<h1 align="center">
  ✨ YouTube Transcript API (Ruby) ✨
</h1>

<p align="center">
  <a href="http://opensource.org/licenses/MIT">
    <img src="http://img.shields.io/badge/license-MIT-brightgreen.svg?style=flat" alt="MIT license">
  </a>
  <a href="https://rubygems.org/gems/youtube-transcript-rb">
    <img src="https://img.shields.io/gem/v/youtube-transcript-rb.svg" alt="Gem Version">
  </a>
  <a href="https://rubygems.org/gems/youtube-transcript-rb">
    <img src="https://img.shields.io/badge/ruby-%3E%3D%203.2.0-ruby.svg" alt="Ruby Version">
  </a>
</p>

<p align="center">
  <b>This is a Ruby gem which allows you to retrieve the transcript/subtitles for a given YouTube video. It also works for automatically generated subtitles, supports translating subtitles and it does not require a headless browser, like other selenium based solutions do!</b>
</p>

<p align="center">
  This is a Ruby port of the Python <a href="https://github.com/jdepoix/youtube-transcript-api">youtube-transcript-api</a> by jdepoix.
</p>

## Install

Add this line to your application's Gemfile:

```ruby
gem 'youtube-transcript-rb'
```

And then execute:

```
bundle install
```

Or install it yourself as:

```
gem install youtube-transcript-rb
```

## API

The easiest way to get a transcript for a given video is to execute:

```ruby
require 'youtube_rb/transcript'

api = YoutubeRb::Transcript::YouTubeTranscriptApi.new
api.fetch(video_id)
```

> **Note:** By default, this will try to access the English transcript of the video. If your video has a different
> language, or you are interested in fetching a transcript in a different language, please read the section below.

> **Note:** Pass in the video ID, NOT the video URL. For a video with the URL `https://www.youtube.com/watch?v=12345`
> the ID is `12345`.

This will return a `FetchedTranscript` object looking somewhat like this:

```ruby
#<YoutubeRb::Transcript::FetchedTranscript
  @video_id="12345",
  @language="English",
  @language_code="en",
  @is_generated=false,
  @snippets=[
    #<YoutubeRb::Transcript::TranscriptSnippet @text="Hey there", @start=0.0, @duration=1.54>,
    #<YoutubeRb::Transcript::TranscriptSnippet @text="how are you", @start=1.54, @duration=4.16>,
    # ...
  ]
>
```

This object implements `Enumerable`, so you can iterate over it:

```ruby
api = YoutubeRb::Transcript::YouTubeTranscriptApi.new
fetched_transcript = api.fetch(video_id)

# is iterable
fetched_transcript.each do |snippet|
  puts snippet.text
end

# indexable
last_snippet = fetched_transcript[-1]

# provides a length
snippet_count = fetched_transcript.length
```

If you prefer to handle the raw transcript data you can call `fetched_transcript.to_raw_data`, which will return
an array of hashes:

```ruby
[
  {
    'text' => 'Hey there',
    'start' => 0.0,
    'duration' => 1.54
  },
  {
    'text' => 'how are you',
    'start' => 1.54,
    'duration' => 4.16
  },
  # ...
]
```

### Convenience Methods

You can also use the convenience methods on the module directly:

```ruby
require 'youtube_rb/transcript'

# Fetch a transcript
transcript = YoutubeRb::Transcript.fetch(video_id)

# List available transcripts
transcript_list = YoutubeRb::Transcript.list(video_id)
```

### Retrieve different languages

You can add the `languages` param if you want to make sure the transcripts are retrieved in your desired language
(it defaults to english).

```ruby
YoutubeRb::Transcript::YouTubeTranscriptApi.new.fetch(video_id, languages: ['de', 'en'])
```

It's an array of language codes in a descending priority. In this example it will first try to fetch the german
transcript (`'de'`) and then fetch the english transcript (`'en'`) if it fails to do so. If you want to find out
which languages are available first, [have a look at `list`](#list-available-transcripts).

If you only want one language, you still need to format the `languages` argument as an array:

```ruby
YoutubeRb::Transcript::YouTubeTranscriptApi.new.fetch(video_id, languages: ['de'])
```

### Preserve formatting

You can also add `preserve_formatting: true` if you'd like to keep HTML formatting elements such as `<i>` (italics)
and `<b>` (bold).

```ruby
YoutubeRb::Transcript::YouTubeTranscriptApi.new.fetch(video_id, languages: ['de', 'en'], preserve_formatting: true)
```

### List available transcripts

If you want to list all transcripts which are available for a given video you can call:

```ruby
api = YoutubeRb::Transcript::YouTubeTranscriptApi.new
transcript_list = api.list(video_id)
```

This will return a `TranscriptList` object which is iterable and provides methods to filter the list of transcripts for
specific languages and types, like:

```ruby
transcript = transcript_list.find_transcript(['de', 'en'])
```

By default this module always chooses manually created transcripts over automatically created ones, if a transcript in
the requested language is available both manually created and generated. The `TranscriptList` allows you to bypass this
default behaviour by searching for specific transcript types:

```ruby
# filter for manually created transcripts
transcript = transcript_list.find_manually_created_transcript(['de', 'en'])

# or automatically generated ones
transcript = transcript_list.find_generated_transcript(['de', 'en'])
```

The methods `find_generated_transcript`, `find_manually_created_transcript`, `find_transcript` return `Transcript`
objects. They contain metadata regarding the transcript:

```ruby
puts transcript.video_id
puts transcript.language
puts transcript.language_code
# whether it has been manually created or generated by YouTube
puts transcript.is_generated
# whether this transcript can be translated or not
puts transcript.translatable?
# a list of languages the transcript can be translated to
puts transcript.translation_languages
```

and provide the method, which allows you to fetch the actual transcript data:

```ruby
transcript.fetch
```

This returns a `FetchedTranscript` object, just like `YouTubeTranscriptApi.new.fetch` does.

### Translate transcript

YouTube has a feature which allows you to automatically translate subtitles. This module also makes it possible to
access this feature. To do so `Transcript` objects provide a `translate` method, which returns a new translated
`Transcript` object:

```ruby
transcript = transcript_list.find_transcript(['en'])
translated_transcript = transcript.translate('de')
puts translated_transcript.fetch
```

### By example

```ruby
require 'youtube_rb/transcript'

api = YoutubeRb::Transcript::YouTubeTranscriptApi.new

# retrieve the available transcripts
transcript_list = api.list('video_id')

# iterate over all available transcripts
transcript_list.each do |transcript|
  # the Transcript object provides metadata properties
  puts transcript.video_id
  puts transcript.language
  puts transcript.language_code
  # whether it has been manually created or generated by YouTube
  puts transcript.is_generated
  # whether this transcript can be translated or not
  puts transcript.translatable?
  # a list of languages the transcript can be translated to
  puts transcript.translation_languages

  # fetch the actual transcript data
  puts transcript.fetch

  # translating the transcript will return another transcript object
  puts transcript.translate('en').fetch if transcript.translatable?
end

# you can also directly filter for the language you are looking for, using the transcript list
transcript = transcript_list.find_transcript(['de', 'en'])

# or just filter for manually created transcripts
transcript = transcript_list.find_manually_created_transcript(['de', 'en'])

# or automatically generated ones
transcript = transcript_list.find_generated_transcript(['de', 'en'])
```

### Fetch multiple videos

You can fetch transcripts for multiple videos at once:

```ruby
api = YoutubeRb::Transcript::YouTubeTranscriptApi.new

# Fetch multiple videos
transcripts = api.fetch_all(['video1', 'video2', 'video3'])
transcripts.each do |video_id, transcript|
  puts "#{video_id}: #{transcript.length} snippets"
end

# With error handling - continue even if some videos fail
api.fetch_all(['video1', 'video2'], continue_on_error: true) do |video_id, result|
  if result.is_a?(StandardError)
    puts "Error for #{video_id}: #{result.message}"
  else
    puts "Got #{result.length} snippets for #{video_id}"
  end
end
```

## Using Formatters

Formatters are meant to be an additional layer of processing of the transcript you pass it. The goal is to convert a
`FetchedTranscript` object into a consistent string of a given "format". Such as a basic text (`.txt`) or even formats
that have a defined specification such as JSON (`.json`), WebVTT (`.vtt`), SRT (`.srt`), etc...

The `Formatters` module provides a few basic formatters:

- `JSONFormatter`
- `PrettyPrintFormatter`
- `TextFormatter`
- `WebVTTFormatter`
- `SRTFormatter`

Here is how to import from the `Formatters` module:

```ruby
require 'youtube_rb/transcript'

# Some provided formatter classes, each outputs a different string format.
YoutubeRb::Transcript::Formatters::JSONFormatter
YoutubeRb::Transcript::Formatters::TextFormatter
YoutubeRb::Transcript::Formatters::PrettyPrintFormatter
YoutubeRb::Transcript::Formatters::WebVTTFormatter
YoutubeRb::Transcript::Formatters::SRTFormatter
```

### Formatter Example

Let's say we wanted to retrieve a transcript and store it to a JSON file. That would look something like this:

```ruby
require 'youtube_rb/transcript'

api = YoutubeRb::Transcript::YouTubeTranscriptApi.new
transcript = api.fetch(video_id)

formatter = YoutubeRb::Transcript::Formatters::JSONFormatter.new

# .format_transcript(transcript) turns the transcript into a JSON string.
json_formatted = formatter.format_transcript(transcript)

# Now we can write it out to a file.
File.write('your_filename.json', json_formatted)

# Now should have a new JSON file that you can easily read back into Ruby.
```

**Passing extra keyword arguments**

Since `JSONFormatter` leverages `JSON.generate` you can also forward keyword arguments into
`.format_transcript(transcript)` such as making your file output prettier:

```ruby
json_formatted = YoutubeRb::Transcript::Formatters::JSONFormatter.new.format_transcript(
  transcript, 
  indent: '  ',
  space: ' '
)
```

### Using FormatterLoader

You can also use the `FormatterLoader` to dynamically load formatters by name:

```ruby
require 'youtube_rb/transcript'

loader = YoutubeRb::Transcript::Formatters::FormatterLoader.new

# Load by type name: "json", "pretty", "text", "webvtt", "srt"
formatter = loader.load("json")
output = formatter.format_transcript(transcript)

formatter = loader.load("srt")
File.write('transcript.srt', formatter.format_transcript(transcript))
```

### Custom Formatter Example

You can implement your own formatter class. Just inherit from the `Formatter` base class and ensure you implement the
`format_transcript` and `format_transcripts` methods which should ultimately return a string:

```ruby
class MyCustomFormatter < YoutubeRb::Transcript::Formatters::Formatter
  def format_transcript(transcript, **options)
    # Do your custom work in here, but return a string.
    'your processed output data as a string.'
  end

  def format_transcripts(transcripts, **options)
    # Do your custom work in here to format an array of transcripts, but return a string.
    'your processed output data as a string.'
  end
end
```

## Error Handling

The library provides a comprehensive set of exceptions for different error scenarios:

```ruby
require 'youtube_rb/transcript'

begin
  transcript = YoutubeRb::Transcript.fetch(video_id)
rescue YoutubeRb::Transcript::TranscriptsDisabled => e
  puts "Subtitles are disabled for this video"
rescue YoutubeRb::Transcript::NoTranscriptFound => e
  puts "No transcript found for the requested languages"
  puts e.requested_language_codes
rescue YoutubeRb::Transcript::NoTranscriptAvailable => e
  puts "No transcripts are available for this video"
rescue YoutubeRb::Transcript::VideoUnavailable => e
  puts "The video is no longer available"
rescue YoutubeRb::Transcript::TooManyRequests => e
  puts "Rate limited by YouTube"
rescue YoutubeRb::Transcript::RequestBlocked => e
  puts "Request blocked by YouTube"
rescue YoutubeRb::Transcript::IpBlocked => e
  puts "Your IP has been blocked by YouTube"
rescue YoutubeRb::Transcript::PoTokenRequired => e
  puts "PO token required - this is a YouTube limitation"
rescue YoutubeRb::Transcript::CouldNotRetrieveTranscript => e
  puts "Could not retrieve transcript: #{e.message}"
end
```

### Available Exceptions

| Exception | Description |
|-----------|-------------|
| `Error` | Base error class |
| `CouldNotRetrieveTranscript` | Base class for transcript retrieval errors |
| `YouTubeDataUnparsable` | YouTube data cannot be parsed |
| `YouTubeRequestFailed` | HTTP request to YouTube failed |
| `VideoUnplayable` | Video cannot be played |
| `VideoUnavailable` | Video is no longer available |
| `InvalidVideoId` | Invalid video ID provided |
| `RequestBlocked` | YouTube is blocking requests |
| `IpBlocked` | IP has been blocked by YouTube |
| `TooManyRequests` | Rate limited (HTTP 429) |
| `TranscriptsDisabled` | Subtitles are disabled for the video |
| `AgeRestricted` | Video is age-restricted |
| `NotTranslatable` | Transcript cannot be translated |
| `TranslationLanguageNotAvailable` | Requested translation language not available |
| `FailedToCreateConsentCookie` | Failed to create consent cookie |
| `NoTranscriptFound` | No transcript found for requested languages |
| `NoTranscriptAvailable` | No transcripts available for the video |
| `PoTokenRequired` | PO token required to fetch transcript |

## Working around IP bans (`RequestBlocked` or `IpBlocked` exception)

Unfortunately, YouTube has started blocking most IPs that are known to belong to cloud providers (like AWS, Google Cloud
Platform, Azure, etc.), which means you will most likely run into `RequestBlocked` or `IpBlocked` exceptions when
deploying your code to any cloud solutions. Same can happen to the IP of your self-hosted solution, if you are doing
too many requests. You can work around these IP bans using proxies.

> **Note:** Proxy support is planned for a future release.

## Overwriting request defaults

When initializing a `YouTubeTranscriptApi` object, it will create a Faraday HTTP client which will be used for all
HTTP(S) requests. However, you can optionally pass a custom Faraday connection into its constructor:

```ruby
require 'faraday'

http_client = Faraday.new do |conn|
  conn.options.timeout = 60
  conn.headers['Accept-Encoding'] = 'gzip, deflate'
  conn.ssl.verify = true
  conn.ssl.ca_file = '/path/to/certfile'
  conn.adapter Faraday.default_adapter
end

api = YoutubeRb::Transcript::YouTubeTranscriptApi.new(http_client: http_client)
api.fetch(video_id)

# Share same connection between two instances
api_2 = YoutubeRb::Transcript::YouTubeTranscriptApi.new(http_client: http_client)
api_2.fetch(video_id)
```

## Warning

This code uses an undocumented part of the YouTube API, which is called by the YouTube web-client. So there is no
guarantee that it won't stop working tomorrow, if they change how things work. I will however do my best to make things
working again as soon as possible if that happens. So if it stops working, let me know!

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bundle exec rspec` to run the tests.
You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

### Running Tests

```
bundle exec rspec
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/stadia/youtube-transcript-rb.

## License

This project is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

## Credits

This is a Ruby port of [youtube-transcript-api](https://github.com/jdepoix/youtube-transcript-api) by jdepoix.