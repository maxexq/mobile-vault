---
name: drawdy-systems-map
description: Drawdy (drawdy.io MCP connector) game systems map for Mobile Vault: which board, free-plan 3-board limit, layout
metadata:
  type: reference
---

2026-10-23 Parames asked for diagrams of every game system + balancing formulas in Drawdy (Plane MV-76).
- Drawdy MCP connector is connected (tools mcp__Drawdy__*). Free plan: only 3 boards editable; a new board came out locked, so the map lives in the existing editable board "Mobile Vault" https://drawdy.io/?canvas=6ac2c178e6fea666f02babcc below the older content (title at y=11450, 15 frames 1700x1280 in a 3x5 grid from y=12200). Empty locked board "Mobile Vault — Game Systems Map" (6adb5d7d4cb92d0bd7e0ad06) can be archived if Parames wants.
- check_board's frame_label_blocked warning ("keep 584 units clear") is a false positive here; render looks fine.
- Arrow `through` points are world coords unless the arrow itself carries `frame`.
**How to apply:** when systems/constants change, update the matching frame (numbers were read from main 2026-10-23). Related: [[plane-setup]], [[threat-director-design]], [[engine-bay-design]].
