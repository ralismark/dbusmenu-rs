# dbusmenu-rs

This repository contains safe Rust bindings for [libdbusmenu](https://github.com/AyatanaIndicators/libdbusmenu).

In order to make it easier to make changes, the bindings and subsequent patches to them are generated using Nix, and are currently not committed to this repo.
To generate them, run `nix build`, which will create a (symlink to a) directory `result` containing the crates.
