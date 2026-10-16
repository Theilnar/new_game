# Player architecture

## Safety rules

The Player scene has several systems that all touch movement, animation and
collision. A feature must not directly rewrite another feature's state.

1. Put feature-specific calculations in `player/features/`.
2. Let `player.gd` call the component at one boundary point.
3. Keep scene effects and state transitions in the orchestrator until the
   feature has tests and a dedicated controller.
4. Make one feature change per commit and run validation after each change.

## Current boundaries

`player.gd` remains the orchestration layer for compatibility. Pipe swing
calculation is isolated in `player/features/pipe_swing_model.gd`; grabbing,
rendering, release and launch remain in `player.gd` because they depend on
scene nodes and the global state machine.

This is intentionally incremental so architecture changes remain separable
from gameplay regressions.
