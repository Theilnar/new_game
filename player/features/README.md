# Player feature components

`player.gd` is currently the compatibility/orchestration layer for the Player
scene. New feature logic should be placed here first and exposed through a
small method or data object instead of adding more state transitions directly
to the 3000-line controller.

Current components:

- `pipe_swing_model.gd` — pure pipe swing physics, without scene or input
  dependencies. `player.gd` remains responsible for grabbing, animation,
  collision, launch and release.
- `ledge_controller.gd` — ledge/fence decisions.
- `ladder_controller.gd` — ladder timers and pose intent.
- `carry_controller.gd` — climb-box state and push/pull animation choice.
- `combat_controller.gd` — melee charge and attack-state decisions.

