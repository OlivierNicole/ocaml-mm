(** Perform and FFT followed by an IFFT, so it should be roughly the
    identity... *)

module FFT = Audio.Mono.Analyze.FFT

let () =
  let read = Audio.IO.reader_of_wav_file Sys.argv.(1) in
  let write = Audio.IO.writer_to_wav_file read#channels read#sample_rate "out.wav" in
  let fft_n = 11 in
  let fft = FFT.init fft_n in
  let blen = 1 lsl fft_n in
  let buf = Audio.create read#channels blen in
  let loop = ref true in
  while !loop do
    let n = read#read buf 0 blen in
    if n = 0 then loop := false;
    let c = FFT.complex_create (Audio.to_mono buf) 0 blen in
    FFT.Window.cosine c;
    FFT.fft fft c;
    let c = Array.map (fun c -> c.Complex.re) c in
    write#write (Array.make read#channels c) 0 blen
  done;
  write#close;
  read#close

