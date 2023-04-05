#![doc = include_str!("../../../README.md")]

pub use dbusmenu_glib as glib;
pub use dbusmenu_gtk3 as gtk;

// re-export individual symbols
#[doc(no_inline)]
pub use dbusmenu_glib::{
    Client,
    Menuitem,
    MenuitemProxy,
    Server,
    Status,
    TextDirection,
};
#[doc(no_inline)]
pub use dbusmenu_gtk3::{
    Client as GtkClient,
    Menu as GtkMenu,
};

pub mod traits {
    #[doc(no_inline)]
    pub use dbusmenu_gtk3::traits::*;
    #[doc(no_inline)]
    pub use dbusmenu_glib::traits::*;

    // NOTE dbusmenu_gtk3 and dbusmenu_glib both have the Client type, so we need to import
    // as a different alias
    #[doc(no_inline)]
    pub use dbusmenu_gtk3::traits::ClientExt as GtkClientExt;
}

/// Traits intended for blanked imports
pub mod prelude {
    pub use crate::traits::*;
}
