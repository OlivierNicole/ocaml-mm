type data = (int, Bigarray.int8_unsigned_elt, Bigarray.c_layout) Bigarray.Array1.t

type frame =
  {
    (* Order matters for C callbacks! *)
    data   : data;
    width  : int;
    height : int;
    stride : int
  }

type color = int * int * int * int

type color_rgb = int * int * int

let rgb_of_int n =
  if n > 0xffffff then raise (Invalid_argument "Not a color");
  (n lsr 16) land 0xff, (n lsr 8) land 0xff, n land 0xff

let create ?stride width height =
  let stride =
    match stride with
      | Some v -> v
      | None -> 4*width
  in
  let data =
    Bigarray.Array1.create
     Bigarray.int8_unsigned Bigarray.c_layout
     (stride*height)
  in
  {
    data   = data;
    width  = width;
    height = height;
    stride = stride
  }

let copy f =
  let nf = create ~stride:f.stride f.width f.height in
  Bigarray.Array1.blit f.data nf.data;
  nf

(* Remove the optional stride argument. *)
let create width height = create width height

external blit : frame -> frame -> unit = "caml_rgb_blit"

external blit_off : frame -> frame -> int -> int -> bool -> unit = "caml_rgb_blit_off"

external blit_off_scale : frame -> frame -> int * int -> int * int -> bool -> unit = "caml_rgb_blit_off_scale"

let blit_fast src dst =
  blit src dst

let blit ?(blank=true) ?(x=0) ?(y=0) ?w ?h src dst =
  match (w,h) with
    | None, None -> blit_off src dst x y blank
    | Some w, Some h -> blit_off_scale src dst (x,y) (w,h) blank
    | _, _ -> assert false

external fill : frame -> color -> unit = "caml_rgb_fill"

external blank : frame -> unit = "caml_rgb_blank" "noalloc"

external of_linear_rgb : frame -> string -> unit = "caml_rgb_of_linear_rgb"

let of_linear_rgb data width =
  let height = (String.length data / 3) / width in
  let ans = create width height in
    of_linear_rgb ans data;
    ans

type yuv = (data *int ) * (data * data * int)

external of_YUV420 : yuv -> frame -> unit = "caml_rgb_of_YUV420"

let of_YUV420_create frame width height =
  let ans = create width height in
    of_YUV420 frame ans;
    ans

external create_yuv : int -> int -> yuv = "caml_yuv_create"

external blank_yuv : yuv -> unit = "caml_yuv_blank"

external to_YUV420 : frame -> yuv -> unit = "caml_rgb_to_YUV420"

external get_pixel : frame -> int -> int -> color = "caml_rgb_get_pixel"

external set_pixel : frame -> int -> int -> color -> unit = "caml_rgb_set_pixel"

external randomize : frame -> unit = "caml_rgb_randomize"

external scale_coef : frame -> frame -> int * int -> int * int -> unit = "caml_rgb_scale"

external bilinear_scale_coef : frame -> frame -> float -> float -> unit = "caml_rgb_bilinear_scale"

let scale src dst =
  let sw, sh = src.width,src.height in
  let dw, dh = dst.width,dst.height in
    scale_coef dst src (dw, sw) (dh, sh)

let scale_create src w h =
  let sw, sh = src.width,src.height in
  let dst = create w h in
    scale_coef dst src (w, sw) (h, sh);
    dst

let proportional_scale ?(bilinear=false) dst src =
  let sw, sh = src.width,src.height in
  let dw, dh = dst.width,dst.height in
  let n, d =
    if dh * sw < sh * dw then
      dh, sh
    else
      dw, sw
  in
    if bilinear then
      let a = float_of_int n /. float_of_int d in
        bilinear_scale_coef dst src a a
    else
      scale_coef dst src (n, d) (n, d)

let proportional_scale_to ?(bilinear=false) src w h =
  let dst = create w h in
    proportional_scale ~bilinear dst src;
    dst

external to_bmp : frame -> string = "caml_rgb_to_bmp"

(*
let save_bmp f fname =
  let oc = open_out_bin fname in
    output_string oc (to_bmp f);
    close_out oc
*)

exception Invalid_format of string

let ppm_header =
  Str.regexp "P6\n\\(#.*\n\\)?\\([0-9]+\\) \\([0-9]+\\)\n\\([0-9]+\\)\n"

let of_ppm ?alpha data =
  (
    try
      if not (Str.string_partial_match ppm_header data 0) then
        raise (Invalid_format "Not a PPM file.");
    with
      | _ -> raise (Invalid_format "Not a PPM file.")
  );
  let w = int_of_string (Str.matched_group 2 data) in
  let h = int_of_string (Str.matched_group 3 data) in
  let d = int_of_string (Str.matched_group 4 data) in
  let o = Str.match_end () in
  let datalen = String.length data - o in
    if d <> 255 then
      raise (Invalid_format (Printf.sprintf "Files of color depth %d \
                                             are not handled." d));
    if datalen < 3*w*h then
      raise (Invalid_format (Printf.sprintf "Got %d bytes of data instead of \
                                             expected %d." datalen (3*w*h)));
    let ans = create w h in
      for j = 0 to h - 1 do
        for i = 0 to w - 1 do
          let r, g, b =
            int_of_char data.[o + 3 * (j * w + i) + 0],
            int_of_char data.[o + 3 * (j * w + i) + 1],
            int_of_char data.[o + 3 * (j * w + i) + 2]
          in
          let a =
            match alpha with
              | Some (ra, ga, ba) ->
                  if r = ra && g = ga && b = ba then 0x00 else 0xff
              | None -> 0xff
          in
            set_pixel ans i j (r, g, b, a);
        done
      done;
      ans

let read_ppm ?alpha fname =
  let ic = open_in_bin fname in
  let len = in_channel_length ic in
  let data = String.create len in
    really_input ic data 0 len;
    close_in ic;
    of_ppm ?alpha data

external to_int_image : frame -> int array array = "caml_rgb_to_color_array"

external add : frame -> frame -> unit = "caml_rgb_add"

let add_fast = add

external add_off : frame -> frame -> int -> int -> unit = "caml_rgb_add_off"

external add_off_scale : frame -> frame -> int * int -> int * int -> unit = "caml_rgb_add_off_scale"

let add ?(x=0) ?(y=0) ?w ?h src dst =
  match (w,h) with
    | None, None -> add_off src dst x y
    | Some w, Some h -> add_off_scale src dst (x,y) (w,h)
    | _, _ -> assert false

module Effect = struct
  external greyscale : frame -> bool -> unit = "caml_rgb_greyscale"

  let sepia buf = greyscale buf true

  let greyscale buf = greyscale buf false

  external invert : frame -> unit = "caml_rgb_invert"

  external rotate : frame -> float -> unit = "caml_rgb_rotate"

  external scale_opacity : frame -> float -> unit = "caml_rgb_scale_opacity"

  external disk_opacity : frame -> int -> int -> int -> unit = "caml_rgb_disk_opacity"

  external affine : frame -> float -> float -> int -> int -> unit = "caml_rgb_affine"

  (* TODO: faster implementation? *)
  let translate f x y =
    affine f 1. 1. x y

  external mask : frame -> frame -> unit = "caml_rgb_mask"

  external lomo : frame -> unit = "caml_rgb_lomo"

  external color_to_alpha : frame -> int * int * int -> int -> unit = "caml_rgb_color_to_alpha"

  external blur_alpha : frame -> unit = "caml_rgb_blur_alpha"
end
