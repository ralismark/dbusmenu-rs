# dbusmenu-rs

This repository contains safe Rust bindings for [libdbusmenu](https://github.com/AyatanaIndicators/libdbusmenu) that work with the [gtk-rs ecosystem](https://gtk-rs.org).
For more information, including examples, see the [libdbusmenu repo](https://github.com/AyatanaIndicators/libdbusmenu).

## Code Generation

Bindings are generated using [gir](https://github.com/gtk-rs/gir).

In order to manage all the steps and fixes involved in code generation, they are built using Nix and symlinked to `result`.
To generate them yourself, run `nix build`.

## License

This project licensed under LGPLv3.
