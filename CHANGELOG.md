## 1.0.0

First release.

- Keyframe timelines (`Timeline`, `Track`, `Keyframe`) on 25 properties: opacity, translate (px and relative), scale, 2D/3D rotate, skew, rectangle and circle clips, feathered edges, tint, brightness, saturation, hue, blur and shimmer.
- Spring curves (`SpringCurve`) and named curves, including `step`.
- Versioned JSON format (`v: 1`) with strict validation and error paths. `Timeline.tryFromJson` returns null instead of throwing.
- `Motion` widget that builds its child once and updates layers every frame. `Motion.builder` passes value channels to the builder.
- Shared `MotionController` scene clock with play, pause, seek and reverse.
- `MotionQuality.reduced` skips blur, shimmer and feather on weak GPUs.
- 19 presets in `MotionPresets`.
- Example app with a showcase, a live motion lab and a frame-timing scene.
