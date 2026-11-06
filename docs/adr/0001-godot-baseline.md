# ADR-0001 — Godot 4.7.2 foundation and browser-safe renderer

Status: Accepted for D01
Date: 2026-11-06

## Context

ACTION-5 must reuse one 3D world across six camera/control perspectives, run on browsers as well as desktop executables, and remain accessible to autonomous coding agents.

## Decision

- Use official Godot 4.7.2-stable and matching export templates.
- Use typed GDScript, not Godot 4 C#, because web export is a primary target.
- Use the GL Compatibility renderer so the WebGL 2 export target stays supported.
- Use a world convention of X horizontal, Y vertical/gravity, and Z depth.
- Set fixed physics processing at 60 Hz. This does **not** make a network-deterministic simulation.
- Keep action-game framework code in `addons/action5/` independently of all demonstration resources.
- D01 owns a disposable debug actor/controller and fixed camera. The generalized six-view system starts in D02, not here.

## Consequences

Web builds must run from an HTTP(S) server. Native and Web exports are smoke-tested in CI. External assets need an attribution inventory. Browser function-key conflicts and multi-mode aiming are handled in D02 and later deliverables.
