# edit_podcast.rb

Minimal script to edit together a podcast with multiple audio streams.

## Example

Suppose you've recorded a podcast using a service like
[Zencastr](https://zencastr.com). When you are done, each speaker will
have an audio file so how do you get a single, merged audio file to
distribute? With `edit_podcast.rb`, you can just run this command:

    $ ./edit_podcast.rb -e Ana.mp3 Bob.mp3 Cloe.mp3 edited_podcast.mp3

If you have in intro and an outro, include those files with the `-i`
and `-o` options. There's no limit to the number of audio
channels. (However, it can be hard to have a conversation with more
than 3 or 4 speakers.) You can even use just one input file if you are
doing a solo podcast.

## Dependencies

You'll need a [Ruby interpretor](https://www.ruby-lang.org/en/) and
[FFmpeg](http://ffmpeg.org/about.html).

## _Caveat utilitor_

I've had good luck editing my podcast tests with this script so far,
but be sure to listen to the results before publishing. This script
could never replace a competent audio editor.

## What's going on under the hood?

Glad you asked. The script builds an FFmpeg command to run on the
command line. If you want to see the command, leave off the `-e` or
`--exec` option. The audio filters are documented in the
[FFmpeg Filters Documentation](http://ffmpeg.org/ffmpeg-filters.html).

First, we remove "impulsive noise" from each channel. That is to say,
get rid of any clicks or pops:

    [0] adeclick [declicked_0];

Next, we (optionally) normalize each channel for loudness:

    [declicked_0] loudnorm=i=-19:lra=6:tp=-1.5 [input_0];

I got the constants from
[this article](https://theaudacitytopodcast.com/why-and-how-your-podcast-needs-loudness-normalization-tap307/),
which also does a great job of explaining the purpose of this step and
giving reasons for each constant. These constants can be controlled
with command-line options.

Per-channel loudness normalization is optional because it only matters
if the channel volumes are substantially different. In at least one
case, I found it introduced distortion when a track has a long section
of silence. It's also one of the most time-consuming step.

Now that each individual file has the same loudness, we mix them
together into a single audio source:

    [input_0][input_1][input_2] amix=inputs=3 [mixed];

I spent more time than I care to admit playing with the
[`amerge` filter](http://ffmpeg.org/ffmpeg-filters.html#amerge-1). Since
we'll end up with a mono audio file in the end, it's not worth
figuring out how the channels are mapped.

Next we remove silence longer than a second from the mixed podcast and
(if they are provided) the intro/outro streams:

    [mixed] silenceremove=stop_periods=-1:stop_duration=1:stop_threshold=-50dB [body];

Mostly I want to get rid of any silence at the start and end of the
session. But this also removes silence (defined as less than -50
decibels<sup>1</sup>) that might be in the middle of an episode. This ought to
clean up awkward pauses where everyone is waiting for someone else to
talk. So don't be afraid of dead air; we're fixing it in post.

Then we cross fade in the intro and out the outro if they are provided:

    [intro][body] acrossfade=d=4 [start];
    [start][outro] acrossfade=d=10:curve1=log:curve2=exp [all];

I set the parameters after quite a bit of fiddling and they might be
specific to the particular bumpers I'm using. Probably I ought to let
users specify this on the command line. But it might be that there's a
better set of defaults. This is a bit of a work in progress.

Next I run a compressor on the whole thing:

    [all] acompressor [compressed];

This reduces the dynamic range, which makes it easier to listen and
control volume. I don't mess with the
[many options](http://ffmpeg.org/ffmpeg-filters.html#acompressor)
available since I don't have any skill in this. Anyway, the defaults
seem pretty good. It's an optional step since the compressor can
sometimes make people sound robotty.

Finally I run the loudness normalizer again on the entire stream. 

I pass a few more parameter to FFmpeg:

* `-ac 1` &mdash; Outputs just one audio channel [because there's no reason for stereo podcasts](https://theaudacitytopodcast.com/tap059-should-you-podcast-in-mono-or-stereo/).

* `-c:a libmp3lame` &mdash; Sets the audio codec to
  [`libmp3lame`](http://lame.sourceforge.net/). FFmpeg is flexible
  about file formats, but we're locking ourselves to MP3, which is
  [the current standard for podcasts](https://create.blubrry.com/manual/creating-podcast-media/audio/audio-formats/).

* `-q:a 4` &mdash; Sets the
  [LAME `compression_level`](http://ffmpeg.org/ffmpeg-all.html#libmp3lame-1)
  to a middling 4.

* `-ab 128k` &mdash; Sets the bitrate to 128k, which is fairly
  standard for podcasts.

* `-ar 48000` &mdash; Set the sample rate to 48000 Hz, which is also typical.



---

1.  The [decibel scale](https://en.wikipedia.org/wiki/Decibel) is
    logarithmic. The human ear is
    [sensitive to 3kHz sounds down to about 0dB](https://www.dspguide.com/ch22/1.htm). So
    we are removing sounds that can't really be heard anyway. It's
    also not technically a peak of -50dB that's detected, but rather
    the
    [root mean square](https://en.wikipedia.org/wiki/Root_mean_square). Signal
    processing is fun!
