#!/usr/bin/ruby

require 'json'
require 'tempfile'

# Function to scan file for mediaconch compliance
def MediaConchScan(input)
  #Policy taken fromn MediaConch Public Policies. Maintainer Peter B. License: CC-BY-4.0+
  mcpolicy = <<EOS
<?xml version="1.0"?>
<policy type="and" name="Audio: &quot;normal&quot; WAV?" license="CC-BY-4.0+">
  <description>This is the common norm for WAVE audiofiles.&#xD;
Any WAVs not matching this policy should be inspected and possibly normalized to conform to this.</description>
  <policy type="or" name="Signed Integer or Float?">
    <rule name="Is signed Integer?" value="Format_Settings_Sign" tracktype="Audio" occurrence="*" operator="=">Signed</rule>
    <rule name="Is floating point?" value="Format_Profile" tracktype="Audio" occurrence="*" operator="=">Float</rule>
  </policy>
  <policy type="and" name="Audio: Proper resolution?">
    <description>This policy defines audio-resolution values that are proper for WAV.</description>
    <policy type="or" name="Valid samplerate?">
      <description>This was not implemented as rule in order to avoid irregular sampling rates.</description>
      <rule name="Audio is 44.1 kHz?" value="SamplingRate" tracktype="Audio" occurrence="*" operator="=">44100</rule>
      <rule name="Audio is 48 kHz?" value="SamplingRate" tracktype="Audio" occurrence="*" operator="=">48000</rule>
      <rule name="Audio is 88.2 kHz?" value="SamplingRate" tracktype="Audio" occurrence="*" operator="=">88200</rule>
      <rule name="Audio is 96 kHz?" value="SamplingRate" tracktype="Audio" occurrence="*" operator="=">96000</rule>
      <rule name="Audio is 192 kHz?" value="SamplingRate" tracktype="Audio" occurrence="*" operator="=">192000</rule>
      <rule name="Audio is 11 kHz?" value="SamplingRate" tracktype="Audio" occurrence="*" operator="=">11025</rule>
      <rule name="Audio is 22.05 kHz?" value="SamplingRate" tracktype="Audio" occurrence="*" operator="=">22050</rule>
    </policy>
    <policy type="or" name="Valid bit depth?">
      <rule name="Audio is 16 bit?" value="BitDepth" tracktype="Audio" occurrence="*" operator="=">16</rule>
      <rule name="Audio is 24 bit?" value="BitDepth" tracktype="Audio" occurrence="*" operator="=">24</rule>
      <rule name="Audio is 32 bit?" value="BitDepth" tracktype="Audio" occurrence="*" operator="=">32</rule>
      <rule name="Audio is 8 bit?" value="BitDepth" tracktype="Audio" occurrence="*" operator="=">8</rule>
    </policy>
  </policy>
  <rule name="Container is RIFF (WAV)?" value="Format" tracktype="General" occurrence="*" operator="=">Wave</rule>
  <rule name="Encoding is linear PCM?" value="Format" tracktype="Audio" occurrence="*" operator="=">PCM</rule>
  <rule name="Audio is 'Little Endian'?" value="Format_Settings_Endianness" tracktype="Audio" occurrence="*" operator="=">Little</rule>
</policy>
EOS
  if ! defined? $policyfile
    $policyfile = Tempfile.new('mediaconch')
    $policyfile.write(mcpolicy)
    $policyfile.rewind
  end
  command = 'mediaconch --Policy=' + $policyfile.path + ' ' + input 
  mcoutcome = `#{command}`
  puts mcoutcome
end

# Function to scan audio stream characteristics
def CheckAudioQuality(input)
  $highdb = Array.new
  $phasewarnings = Array.new
  ffprobeout = JSON.parse(`ffprobe -print_format json -show_entries frame_tags=lavfi.astats.Overall.Peak_level,lavfi.aphasemeter.phase -f lavfi -i "amovie='#{input}',astats=metadata=1,aphasemeter=video=0"`)
  ffprobeout['frames'].each_with_index do |metadata, index|
    peaklevel = ffprobeout['frames'][index]['tags']['lavfi.astats.Overall.Peak_level'].to_f
    audiophase = ffprobeout['frames'][index]['tags']['lavfi.aphasemeter.phase'].to_f
    if peaklevel > -5.5
      $highdb << peaklevel
    end
    if audiophase < -0.3
      $phasewarnings << audiophase
    end
  end
  if $highdb.count > 0
    puts "WARNING! HIGH LEVELS DETECTED IN #{input}"
  end
  if $phasewarnings.count > 0
    puts puts "WARNING! HIGH LEVELS DETECTED IN #{input}"
    puts $phasewarnings.count
  end
end

ARGV.each do |fileinput|
  CheckAudioQuality(fileinput)
  MediaConchScan(fileinput)
end