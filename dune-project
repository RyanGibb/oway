(lang dune 3.7)

(name oway)

(generate_opam_files true)

(source
 (github RyanGibb/oway))

(authors "Ryan Gibb")

(maintainers "Ryan Gibb")

(license LICENSE)

(documentation https://github.com/RyanGibb/oway)

(package
 (name oway)
 (synopsis "A short synopsis")
 (description "An OCaml Wayland Compositor")
 (depends ocaml dune)
 (tags
  (ocaml wayland)))

