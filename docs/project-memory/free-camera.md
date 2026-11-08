---
name: free-camera
description: MV-723 free camera: whole-step pinch/wheel zoom around the fingers, 2-axis pan, FIT button back to AUTO (switch free_cam)
metadata:
  type: project
  modified: 2026-11-08
---

2026-11-08 Parames asked: "ทำมุมกล้องซูมได้แบบอิสระ + ปุ่มปรับมุมกล้องอัตโนมัติ". Plane MV-723, branch mv-723-free-camera, PR into staging.
- "Free" zoom stays pixel-perfect: it walks EVERY whole-number world scale (free_min_ws = wide - view.free_out .. free_max_ws = view.free_in x UI scale, at least AUTO), not a fractional Camera2D zoom. zoom_mode "free" is never saved to Settings.
- Zoom anchors the world point under the cursor / pinch midpoint (manual math: camera.position + focus*view_k - vp/2, then _fit_camera() synchronously, then pan from the new cam_home).
- Vertical free pan limits come from the content (sky above roof .. FREE_Y_DOWN ground under the road), stored in _free_pan_y by _fit_camera; limits relative to cam_home broke anchoring because cam_home.y moves a lot between scales. When the whole vehicle fits, the road is pinned low (the backdrop ends under the road), so vertical anchoring is lost there by design.
- HUD FIT button (CamFitButton) next to the zoom button; yellow while camera_moved(). No free drift-back; is_calm allows a panned free view.
- Old ladder tests (_portrait_fit_test, _touch_test pinch) run with free_cam forced off; new group `--only=free_cam`.
**How to apply:** any new camera gesture goes through zoom_step(dir, focus) / _clamp_pan() / _place_camera(). Related: [[mobile-touch-input]], [[parallax-v2-ingame]], [[feature-flags-design]].
