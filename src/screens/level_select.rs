use bevy::prelude::*;

use crate::resources::{ActionHistory, LevelProgress, PlayerSelection};
use crate::systems::LevelHandle;

use super::{despawn_screen_ui, GameScreen, ScreenUiRoot};

#[derive(Resource, Default)]
struct LevelMenuSelection(usize);

#[derive(Component)]
struct LevelMenuText;

pub(super) struct LevelSelectPlugin;

impl Plugin for LevelSelectPlugin {
    fn build(&self, app: &mut App) {
        app.init_resource::<LevelMenuSelection>()
            .add_systems(OnEnter(GameScreen::LevelSelect), spawn_level_select_screen)
            .add_systems(OnExit(GameScreen::LevelSelect), despawn_screen_ui)
            .add_systems(
                Update,
                level_menu_input_system.run_if(in_state(GameScreen::LevelSelect)),
            );
    }
}

fn spawn_level_select_screen(
    mut commands: Commands,
    progress: Res<LevelProgress>,
    mut selection: ResMut<LevelMenuSelection>,
) {
    selection.0 = selection.0.min(progress.levels.len().saturating_sub(1));

    commands.spawn((
        Node {
            position_type: PositionType::Absolute,
            left: Val::Px(32.0),
            top: Val::Px(32.0),
            ..default()
        },
        Text::new(level_menu_text(&progress.levels, selection.0)),
        TextFont {
            font_size: 24.0,
            ..default()
        },
        TextColor(Color::WHITE),
        ScreenUiRoot,
        LevelMenuText,
    ));
}

fn level_menu_text(levels: &[String], selected: usize) -> String {
    let mut text = String::from("maps/\n");
    for index in 0..levels.len() {
        let marker = if index == selected { ">" } else { " " };
        text.push_str(&format!("{marker} lvl_{index}.txt\n"));
    }
    text.push_str("\n[W/S] or arrows: select   [Enter] open   [Esc] back");
    text
}

fn level_menu_input_system(
    keyboard: Res<ButtonInput<KeyCode>>,
    mut progress: ResMut<LevelProgress>,
    mut selection: ResMut<LevelMenuSelection>,
    mut menu_text: Query<&mut Text, With<LevelMenuText>>,
    mut level_handle: ResMut<LevelHandle>,
    mut action_history: ResMut<ActionHistory>,
    mut player_selection: ResMut<PlayerSelection>,
    mut next_screen: ResMut<NextState<GameScreen>>,
) {
    if keyboard.just_pressed(KeyCode::Escape) {
        next_screen.set(GameScreen::MainMenu);
        return;
    }

    let level_count = progress.levels.len();
    if level_count == 0 {
        return;
    }

    if (keyboard.just_pressed(KeyCode::ArrowDown) || keyboard.just_pressed(KeyCode::KeyS))
        && selection.0 + 1 < level_count
    {
        selection.0 += 1;
    } else if (keyboard.just_pressed(KeyCode::ArrowUp) || keyboard.just_pressed(KeyCode::KeyW))
        && selection.0 > 0
    {
        selection.0 -= 1;
    }

    for mut text in &mut menu_text {
        **text = level_menu_text(&progress.levels, selection.0);
    }

    if keyboard.just_pressed(KeyCode::Enter) || keyboard.just_pressed(KeyCode::NumpadEnter) {
        progress.current_index = selection.0;
        progress.win_emitted = false;
        level_handle.0 = progress.levels[selection.0].clone();
        action_history.clear();
        player_selection.active_player = None;
        next_screen.set(GameScreen::Playing);
    }
}
