pub mod character_movement;
pub mod level_progression;
pub mod level_spawner;
pub mod player_movement;
pub mod player_outline;
pub mod player_selection;
pub mod undo;

pub use character_movement::character_movement_system;
pub use level_progression::{
    advance_level_system, animate_level_transition_system, begin_level_transition_system,
    check_level_win_system, setup_transition_overlay, LevelTransition, LevelWin, BASE_CAMERA_SCALE,
};
pub use level_spawner::{load_levels, spawn_level, LevelHandle};
pub use player_movement::{player_movement_system, PlayerMoveEvent};
pub use player_outline::{
    active_player_outline_system, spawn_player_outline_system, PlayerOutlineTextures,
};
pub use player_selection::switch_active_player_system;
pub use undo::undo_system;
