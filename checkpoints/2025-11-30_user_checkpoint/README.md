Checkpoint snapshot created on 2025-11-30.

Files included:
- lib/services/pdf_export_service.dart  -- Updated PDF builder that accepts optional rinkPng and heatmapPng. Removes coordinates and goalie names from descriptions and places rink image above heatmap.
- lib/screens/game_details_screen.dart -- Adds RepaintBoundary keys for rink and heatmap and captures PNGs for PDF export.
- lib/gen_pdf_runner.dart -- Flutter runner placeholder for in-app generation (not runnable as pure Dart CLI).
- bin/generate_game_pdf.dart -- Helper placeholder noting that offline generation needs pre-captured PNGs.
- lib/services/stats_aggregator.dart -- Shared aggregator used by UI and PDF for parity.

How to test:
1. Launch the app on an emulator or device.
2. Open a game's details screen.
3. Tap the PDF export icon in the AppBar.
4. Verify the generated PDF contains:
   - Rink image above heatmap
   - Heatmap
   - Shots table (no raw coordinates or goalie names)
   - Scoring summary (no coordinates/goalie names, assists resolved)
   - Events list (no coordinates)
   - Player and goalie stats matching the UI

Notes:
- If the PDF shows missing characters, consider embedding a Unicode-capable font in the PDF builder.
- Generating the PDF from this environment requires Flutter desktop build tools (CMake) and a running Flutter engine; testing on the user's emulator/device is recommended.
