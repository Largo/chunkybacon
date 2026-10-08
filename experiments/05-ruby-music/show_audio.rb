# show_audio - a sound player below a cell, with a picture of the wave.
#
# PROOF OF CONCEPT, kept out of html/main.rb: this file reopens the kernel
# (ChunkyApp) at run time, so it can be pasted into a cell of the real page
# and tried without touching shared files (measure_in_page.mjs does that).
# It hooks into the output through pdfs_html, which run_cell calls after
# every run; NOTES.md has the proper edit to run_cell instead.
#
#   show_audio wav_bytes            # a WAV file as a String ("RIFF....WAVE")
#   show_audio "melodie.wav"        # a file the cell wrote
#   show_audio samples              # an Array of Floats in -1..1 (22050 Hz)
#   show_audio samples, rate: 8000
module ChunkyAudio
  WAVE_W = 360    # overview: the whole sound, one column per pixel
  ZOOM_W = 140    # magnifier: 12 ms around the loudest moment
  WAVE_H = 64

  def add_audio(bytes)
    (@run_audios ||= []) << bytes.b if @run_images   # only during a run
  end

  # run_cell calls pdfs_html once per run, right after the pictures
  def pdfs_html(idx)
    super + audios_html(idx)
  end

  # <audio> on a Blob URL, like show_pdf; the cell's previous URLs are
  # released first
  def audios_html(idx)
    @audio_urls ||= {}
    (@audio_urls[idx] || []).each { |url| $window.URL.revokeObjectURL(url) }
    audios = @run_audios || []
    @run_audios = []
    @audio_urls[idx] = audios.map { |bytes| $window.makeDownloadUrl([bytes].pack("m0"), "audio/wav") }
    audios.zip(@audio_urls[idx]).map do |bytes, url|
      "<div class=\"cell-audio\" style=\"margin:.5em 0\">#{waveform_svg(bytes)}" \
        "<audio controls preload=\"auto\" src=\"#{url}\" style=\"display:block;width:#{WAVE_W + ZOOM_W + 8}px;max-width:100%\"></audio></div>"
    end.join
  end

  # 16-bit PCM samples of the first channel, as -1.0..1.0, plus the rate
  def pcm(bytes)
    pos = 12
    channels = 1
    rate = 22_050
    while pos + 8 <= bytes.bytesize
      id, size = bytes.byteslice(pos, 8).unpack("a4V")
      if id == "fmt "
        _format, channels, rate = bytes.byteslice(pos + 8, 8).unpack("vvV")
      elsif id == "data"
        all = bytes.byteslice(pos + 8, size).unpack("s<*")
        all = all.each_slice(channels).map(&:first) if channels > 1
        return [all, rate]
      end
      pos += 8 + size + (size & 1)
    end
    [[], rate]
  end

  def waveform_svg(bytes)
    samples, rate = pcm(bytes)
    return "" if samples.empty?

    mid = WAVE_H / 2.0
    y = ->(s) { (mid - s * (mid - 2) / 32_768.0).round(1) }
    per = (samples.size.fdiv(WAVE_W)).ceil
    bars = samples.each_slice(per).with_index.map do |slice, x|
      lo, hi = slice.minmax
      "M#{x}.5 #{y.(hi)}V#{[y.(lo), y.(hi) + 0.5].max}"
    end.join
    # the magnifier: 12 ms around the loudest sample, so the shape of the
    # wave (sine, square, saw) shows
    width = (rate * 0.012).round
    loudest = samples.each_with_index.max_by { |s, _i| s.abs }.last
    from = (loudest - width / 2).clamp(0, [samples.size - width, 0].max)
    window = samples[from, width]
    points = window.each_with_index.map { |s, i| "#{(i * ZOOM_W.fdiv(width)).round(1)},#{y.(s)}" }.join(" ")
    seconds = samples.size.fdiv(rate)
    "<svg width=\"#{WAVE_W + ZOOM_W + 8}\" height=\"#{WAVE_H}\" role=\"img\" aria-label=\"#{format('%.2f', seconds)} s\" style=\"display:block;max-width:100%\">" \
      "<rect width=\"#{WAVE_W}\" height=\"#{WAVE_H}\" rx=\"4\" fill=\"#fff4e8\"/>" \
      "<path d=\"#{bars}\" stroke=\"#d9643a\" stroke-width=\"1\" fill=\"none\"/>" \
      "<g transform=\"translate(#{WAVE_W + 8} 0)\"><rect width=\"#{ZOOM_W}\" height=\"#{WAVE_H}\" rx=\"4\" fill=\"#fff4e8\"/>" \
      "<line x1=\"0\" x2=\"#{ZOOM_W}\" y1=\"#{mid}\" y2=\"#{mid}\" stroke=\"#e8c9b0\"/>" \
      "<polyline points=\"#{points}\" stroke=\"#8a3b1f\" stroke-width=\"1.5\" fill=\"none\"/>" \
      "<text x=\"#{ZOOM_W - 4}\" y=\"12\" font-size=\"10\" text-anchor=\"end\" fill=\"#8a3b1f\">12 ms</text></g>" \
      "<text x=\"#{WAVE_W - 4}\" y=\"12\" font-size=\"10\" text-anchor=\"end\" fill=\"#8a3b1f\">#{format('%.2f', seconds)} s</text></svg>"
  end

  # an Array of samples as a WAV, for show_audio(samples)
  def self.wav(samples, rate)
    data = samples.map { |s| (s.to_f.clamp(-1.0, 1.0) * 32_767).round }.pack("s<*")
    ["RIFF", 36 + data.bytesize, "WAVE", "fmt ", 16, 1, 1, rate, rate * 2, 2, 16,
     "data", data.bytesize].pack("a4Va4a4VvvVVvva4V") + data
  end
end

ChunkyApp.prepend(ChunkyAudio) unless ChunkyApp.ancestors.include?(ChunkyAudio)

module Kernel
  def show_audio(sound, rate: 22_050)
    bytes = if sound.is_a?(Array)
              ChunkyAudio.wav(sound, rate)
            elsif sound.to_s.b.start_with?("RIFF")
              sound.to_s
            elsif SandboxFS.virtual?(sound.to_s) && SandboxFS.exist?(sound.to_s)
              SandboxFS.read(sound.to_s)
            else
              File.binread(sound.to_s)
            end
    ChunkyApp.instance.add_audio(bytes)
    nil
  end
end
