mod level_select;
mod main_menu;
mod playing;

use bevy::{hierarchy::DespawnRecursiveExt, prelude::*};

#[derive(States, Default, Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum GameScreen {
    #[default]
    MainMenu,
    LevelSelect,
    Playing,
}

#[derive(Component)]
struct ScreenUiRoot;

#[derive(Resource, Default)]
pub struct PauseMenuState {
    pub is_open: bool,
    pub selected_option: usize,
    pub block_gameplay_this_frame: bool,
}

pub fn gameplay_is_active(screen: Res<State<GameScreen>>, pause_menu: Res<PauseMenuState>) -> bool {
    *screen.get() == GameScreen::Playing
        && !pause_menu.is_open
        && !pause_menu.block_gameplay_this_frame
}

fn despawn_screen_ui(mut commands: Commands, screens: Query<Entity, With<ScreenUiRoot>>) {
    for screen in &screens {
        commands.entity(screen).despawn_recursive();
    }
}

pub struct GameScreensPlugin;

impl Plugin for GameScreensPlugin {
    fn build(&self, app: &mut App) {
        app.init_state::<GameScreen>().add_plugins((
            main_menu::MainMenuPlugin,
            level_select::LevelSelectPlugin,
            playing::PlayingScreenPlugin,
        ));
    }
}
