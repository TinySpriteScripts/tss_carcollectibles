# TSS Car Collectibles

one-time collectible sets for StreetKings.

## Adding collectibles

Edit `config.lua`, then append positions to a set's `locations` list:

```lua
locations = {
    vector3(21.04, 432.12, 857.3),
    vector3(100.25, -220.5, 30.75),
}
```

Do not reorder or delete released locations: save IDs use `set_id:index`. Append new
positions instead. A set can override `floatHeight`, `bobHeight`, `bobSpeed`, and
`rotationSpeed`.

Progress is saved under `carCollectibles.collected` in the active StreetKings save.
There are no blips or trackers. The player must drive through an item as the vehicle's
driver to collect it.
