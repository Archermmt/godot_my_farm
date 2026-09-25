# Asset License Manifest

| File | Purpose | Source / method | Author | License | Cost | Modified |
|---|---|---|---|---|---|---|
| `assets/art/characters/player_placeholder.png` | T03 development player sprite sheet | Generated locally by `tools/generate_player_placeholder.gd`; original rectangle-based pixel design | Project-generated | CC0-1.0 | 0 | No |
| `assets/art/tiles/world_tiles.svg` | T04 farm, field, and cabin development TileSet atlas | Original locally authored pixel-pattern SVG | Project-generated | CC0-1.0 | 0 | No |
| `assets/art/items/harvestable_stages.svg` | T09 tree, rock, stump, and grass health-stage placeholder atlas | Original locally authored vector shapes | Project-generated | CC0-1.0 | 0 | No |
| `assets/art/items/item_icons.svg` | T05/T07-T09 tool, seed, crop, harvestable, material, food, and produce icon atlas | Original locally authored vector shapes | Project-generated | CC0-1.0 | 0 | No |
| `assets/art/ui/weather_icons.svg` | T10 clear, cloudy, rain, storm, and snow status icons | Original locally authored vector shapes | Project-generated | CC0-1.0 | 0 | No |
| `data/game_config.tres` generated tones | T12 development UI, tool, pickup, footstep, and ambient feedback | Original sine-wave placeholders generated at runtime from project-authored frequency/duration definitions | Project-generated | CC0-1.0 | 0 | No |
| `assets/art/effects/wood_chip.svg` | T12 chopping particle texture | Original locally authored vector shape | Project-generated | CC0-1.0 | 0 | No |
| `assets/art/effects/grass_blade.svg` | T12 grass-cutting particle texture | Original locally authored vector shape | Project-generated | CC0-1.0 | 0 | No |
| `assets/art/effects/stone_chip.svg` | T12 mining particle texture | Original locally authored vector shape | Project-generated | CC0-1.0 | 0 | No |
| `assets/art/effects/raindrop.svg` | T12 rain particle texture | Original locally authored vector shape | Project-generated | CC0-1.0 | 0 | No |
| `assets/art/effects/ripple.svg` | T12 ground ripple particle texture | Original locally authored vector shape | Project-generated | CC0-1.0 | 0 | No |
| `assets/art/external/tiny_farm_purchased/` | Purchased Farm RPG - Tiny Asset Pack source archive; kept unchanged as the attribution/reference copy | User-provided purchase from EmanuelleDev | EmanuelleDev | Commercial/non-commercial use; modification allowed; redistribution/resale of the pack prohibited; attribution required | Purchased by user | No |
| `assets/art/runtime/tiny_farm/*_stages.png` | Runtime crop stage atlases derived from the purchased pack without resizing | Cropped/selected native 16x16 frames from `external/tiny_farm_purchased/Crops` | EmanuelleDev | Same pack license; derived runtime files are part of this project and must retain attribution | Purchased by user | Yes |
| `assets/art/runtime/tiny_farm/world_tiles.png` | Runtime 32x32 world TileSet atlas assembled from native 16x16 purchased tiles | `tools/build_tiny_farm_runtime_atlas.gd` | EmanuelleDev | Same pack license; no source pixels rescaled | Purchased by user | Yes |
| `assets/art/runtime/tiny_farm/player_atlas.png` | Runtime 6x4 player/NPC animation atlas assembled from native 32x32 Alex Idle/Walk frames | `tools/build_tiny_farm_runtime_atlas.gd` | EmanuelleDev | Same pack license; left-facing frames are native horizontal flips | Purchased by user | Yes |

Purchased pack attribution: EmanuelleDev, https://emanuelledev.itch.io. The full license text is preserved at `assets/art/external/tiny_farm_purchased/Documentation.txt`.

This manifest will expand as later tasks add distributable art, audio, fonts, and effects.
