module C = Configurator.V1

external is_big_endian : unit -> bool = "ocaml_mm_is_big_endian"

let () =
  C.main ~name:"mm" (fun c ->
      let has_aligned_alloc =
        C.c_test c
          {|
        #include <stdlib.h>
        int main() {
          char *data = aligned_alloc(16, 4096);
          return 0;
        }
      |}
      in

      let has_memalign =
        C.c_test c
          {|
        #include <malloc.h>
        int main() {
          char *data = memalign(16, 4096);
          return 0;
        }
      |}
      in

      let has_max_align_t =
        C.c_test c
          {|
        #include <stddef.h>
        #include <stdalign.h>
        int main() {
          size_t x = alignof(max_align_t);
          return 0;
        }
      |}
      in

      let has_caml_internals =
        C.c_test c
          {|
        #define CAML_INTERNALS 1
        #include <caml/bigarray.h>
        int main() {
          int x = caml_ba_element_size[0];
          return 0;
        }
|}
      in

      C.C_define.gen_header_file c ~fname:"config.h"
        [
          ("BIGENDIAN", Switch (is_big_endian ()));
          ("HAS_ALIGNED_ALLOC", Switch has_aligned_alloc);
          ("HAS_MEMALIGN", Switch has_memalign);
          ("HAS_MAX_ALIGN_T", Switch has_max_align_t);
          ("HAS_CAML_INTERNALS", Switch has_caml_internals);
        ])
