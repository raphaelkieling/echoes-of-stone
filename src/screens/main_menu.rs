use bevy::prelude::*;

use super::{despawn_screen_ui, GameScreen, ScreenUiRoot};

#[derive(Resource, Default)]
struct MainMenuSelection(usize);

#[derive(Component)]
struct MainMenuText;

pub(super) struct MainMenuPlugin;

impl Plugin for MainMenuPlugin {
    fn build(&self, app: &mut App) {
        app.init_resource::<MainMenuSelection>()
            .add_systems(OnEnter(GameScreen::MainMenu), spawn_main_menu_screen)
            .add_systems(OnExit(GameScreen::MainMenu), despawn_screen_ui)
            .add_systems(
                Update,
                main_menu_input_system.run_if(in_state(GameScreen::MainMenu)),
            );
    }
}

fn spawn_main_menu_screen(mut commands: Commands, mut selection: ResMut<MainMenuSelection>) {
    selection.0 = 0;

    commands.spawn((
        Node {
            position_type: PositionType::Absolute,
            left: Val::Px(32.0),
            bottom: Val::Px(32.0),
            ..default()
        },
        Text::new(main_menu_text(selection.0)),
        TextFont {
            font_size: 28.0,
            ..default()
        },
        TextColor(Color::WHITE),
        ScreenUiRoot,
        MainMenuText,
    ));
}

fn main_menu_text(selected: usize) -> String {
    format!(
        "SOKOBAN\n\n{} START\n{} QUIT",
        if selected == 0 { ">" } else { " " },
        if selected == 1 { ">" } else { " " },
    )
}

fn main_menu_input_system(
    keyboard: Res<ButtonInput<KeyCode>>,
    mut selection: ResMut<MainMenuSelection>,
    mut menu_text: Query<&mut Text, With<MainMenuText>>,
    mut next_screen: ResMut<NextState<GameScreen>>,
    mut app_exit: EventWriter<AppExit>,
) {
    if keyboard.just_pressed(KeyCode::ArrowDown) || keyboard.just_pressed(KeyCode::KeyS) {
        selection.0 = (selection.0 + 1) % 2;
    } else if keyboard.just_pressed(KeyCode::ArrowUp) || keyboard.just_pressed(KeyCode::KeyW) {
        selection.0 = (selection.0 + 1) % 2;
    }

    for mut text in &mut menu_text {
        **text = main_menu_text(selection.0);
    }

    if keyboard.just_pressed(KeyCode::Enter) || keyboard.just_pressed(KeyCode::NumpadEnter) {
        match selection.0 {
            0 => next_screen.set(GameScreen::LevelSelect),
            _ => {
                app_exit.send(AppExit::Success);
            }
        }
    }
}
