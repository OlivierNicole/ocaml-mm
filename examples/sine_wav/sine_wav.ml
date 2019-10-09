let total_duration = 10

let () =
  let channels = 2 in
  let sample_rate = 44100 in
  let ao = new MMAO.writer channels sample_rate in
  let wav = new Audio.IO.Writer.to_wav_file channels sample_rate "out.wav" in
  let blen = 1024 in
  let buf = Audio.create channels blen in
  let sine = new Audio.Generator.of_mono (new Audio.Mono.Generator.sine sample_rate 440.) in
  for i = 0 to sample_rate / blen * total_duration - 1 do
    sine#fill buf;
    wav#write buf;
    ao#write buf
  done;
  wav#close;
  ao#close
