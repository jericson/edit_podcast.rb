#!/usr/bin/env ruby -W1
# encoding: UTF-8

require 'optparse'

options = {
  :loudness => -19,
  :lra => 6,
  :tp => -1.5,
  :exec => false
}

optparse = OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [--exec] [-i intro] [-o outro] audio_channel ... destination"

  opts.on("-i", "--intro NAME", "Intro file") do |s|
    options[:intro] = s
  end

  opts.on("-o", "--outro NAME", "Outro file") do |s|
    options[:outro] = s
  end

  opts.on( '-e', '--exec', 'Execute ffmpeg command') do
    options[:exec] = true
  end
  
  opts.on( '-h', '--help', 'Display this screen' ) do
    puts opts
    exit
  end
end

optparse.parse!

if ARGV.length < 2
  abort(optparse.help)
end

options[:output] = ARGV.pop

command="ffmpeg"

ARGV.each do | file |
  command += " -i #{file}"
end

if options[:intro]
  command += " -i #{options[:intro]}"
end

if options[:outro]
  command += " -i #{options[:outro]}"
end

command += ' -filter_complex \
"'

ARGV.each_index do | i |
  command += "
   [#{i}] loudnorm=i=#{options[:loudness]}:lra=#{options[:lra]}:tp=#{options[:tp]} [input_#{i}];"
end

command += "
   "

ARGV.each_index do | i |
  command += "[input_#{i}]"
end

command += " amix=inputs=#{ARGV.length} [mixed];"

command += "
   [mixed] silenceremove=stop_periods=-1:stop_duration=1:stop_threshold=-50dB [body];"

input_cnt=ARGV.length

if options[:intro]
  command += "
   [#{input_cnt}] silenceremove=stop_periods=-1:stop_duration=1:stop_threshold=-50dB [intro_trimmed];
    [intro_trimmed] loudnorm=i=#{options[:loudness]}:lra=#{options[:lra]}:tp=#{options[:tp]} [intro];
   [intro][body] acrossfade=d=4 [start];"
  input_cnt += 1 
else
  command += "
   [body] acopy [start];"
end

if options[:outro]
  command += "
   [#{input_cnt}] silenceremove=stop_periods=-1:stop_duration=1:stop_threshold=-50dB [outro_trimmed];
    [outro_trimmed] loudnorm=i=#{options[:loudness]}:lra=#{options[:lra]}:tp=#{options[:tp]} [outro];
   [start][outro] acrossfade=d=10:curve1=log:curve2=exp [all];"
  input_cnt += 1
else
  command += "
   [start] acopy [all];"
end

command += "
   [all] acompressor [compressed];
   [compressed] loudnorm=i=#{options[:loudness]}:lra=#{options[:lra]}:tp=#{options[:tp]}\" \\
  -ac 1 -c:a libmp3lame -q:a 4  -ab 128k -ar 48000 #{options[:output]}"

if options[:exec]
  system(command)
else
  puts(command)
end
