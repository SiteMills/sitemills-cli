# Games Guide

SiteMills projects can be games. There are two kinds:

- **3D games on the SiteMills game engine.** A game here is a Roblox place written in TypeScript: Roblox's classes and services (parts, physics, constraints, characters, tools, GUIs, sounds, data stores, pathfinding), split between server and client as Roblox splits them. Everyone who opens the game plays together in a room, and it plays on phones. Use it for obbies, shooters, racing, strategy, tycoons, simulators and open worlds. This guide is mostly about these.
- **2D games with Phaser**, in an ordinary SiteMills React project ([section 8](#8-2d-games-with-phaser)).

Both can use the **SiteMills game asset library**: about 68,000 CC0 models, sprites, tiles, sound effects and fonts, plus hand-picked kits.

Run `sitemills-cli help games` for a short version of this guide.

---

## 1. Start from a starter game

```bash
sitemills-cli login
sitemills-cli game templates
sitemills-cli game create "Kart Party" --template racing
cd kart-party
```

`game create` makes a new app from a starter game, downloads it into a folder (the game's name in lower case, or the folder you give after the name) and links the folder to the app, so `check` and `push` work inside it. The folder also gets the engine and its reference.

Pick the starter game closest to yours. Every one is a whole, working game with tests:

| Template | What it is | Its files |
|---|---|---|
| `baseplate` | An empty world: a baseplate and a spawn. For any game that doesn't fit another one. | [baseplate.md](games/templates/baseplate.md) |
| `obby` | An obstacle course: jumps, lava, checkpoints, a moving platform, best times kept. | [obby.md](games/templates/obby.md) |
| `shooter` | A first-person wave shooter: zombies, a blaster, cover, a scoreboard on the wall. | [shooter.md](games/templates/shooter.md) |
| `racing` | A kart race: a countdown, three laps, places, best laps kept. | [racing.md](games/templates/racing.md) |
| `rts` | Real-time strategy seen from above, with no avatar: workers, gold, soldiers, raiders, victory and defeat. | [rts.md](games/templates/rts.md) |
| `world` | An open town: coins to collect, a car anyone can drive, a shop, townsfolk walking about. | [world.md](games/templates/world.md) |

`sitemills-cli game templates` always has the current list.

**Without the command.** Each page above has every file of its starter game, in full. Write them into an empty folder, then:

```bash
sitemills-cli import "Kart Party" ./kart-party          # prints the new app's project ID
sitemills-cli export <projectId> ./kart-party           # adds the engine and links the folder
```

---

## 2. What's in the folder

| Path | What it is | In Roblox |
|---|---|---|
| `server/game/place.ts` | Builds the world and runs the game, on the server | The place and its Scripts |
| `server/game/client.ts` | Runs in each player's page: HUD, input, camera | LocalScripts |
| `server/game/tests.ts` | The game's tests. They run on every push. | |
| `server/game/*.ts` | More of the game's code, imported by the files above | ModuleScripts |
| `server/rooms/game_room.ts` | Runs the place in a room for online play | The server |
| `src/pages/Game.tsx`, `src/App.tsx` | The page that plays the game, at `/` | |
| `server/framework/`, `src/framework/` | **The engine.** The platform supplies it: don't edit it. | |
| `server/framework/ENGINE.md`, `server/framework/docs/` | **The engine's reference.** Read it before you write the game. | |
| `sitemills.json` | Says the app is on the React stack and which engine version it uses. Don't change it. | |

The engine is the platform's. Your app's `sitemills.json` names the version it uses (`"gameFramework": "1.0"`), and the platform supplies that version to every build. A push leaves out the engine's files, and refuses a change to one: put every change in your game's own files.

---

## 3. Read the engine's reference

`server/framework/ENGINE.md` is the reference for the version your game runs:

- the differences from Roblox (Luau to TypeScript);
- every class and service there is;
- recipes every game needs: touch, tags, checkpoints, leaderstats saved between visits, a HUD, remotes, input and the camera, sounds and teams;
- how to write tests, and the limits.

`server/framework/docs/` has a page for each kind of game. Read the ones your game needs before you write that part:

| Page | Read it for |
|---|---|
| `tools-and-prompts.md` | A tool a player holds and clicks with (a blaster, a sword); a button to press on a part |
| `vehicles.md` | A car, and a fast car driven from the client script |
| `npcs.md` | NPCs that walk and find paths; crowds; collision groups |
| `strategy.md` | A game with no avatar: a camera over the map, picking units, orders |
| `world.md` | Terrain; 3D models from the game asset library; characters drawn as animated models |
| `animation.md` | Characters' movements: a sword swing or a wave, emotes, turning a joint |
| `effects.md` | Fire, smoke, particles, explosions and lights; beams, trails, decals and textures |
| `movers.md` | Knockback, a dash, flying, a hovering platform; thick raycasts |
| `gui.md` | GUIs that fit any screen, gradients, rich text, notifications, GUIs on parts |
| `chat.md` | Doing something with chat (it's there without code): commands, announcements |

Where those pages say `agent.gameAssets.search(...)`, that's the SiteMills agent's way to search the asset library. From the CLI, it's `sitemills-cli game-assets search` ([section 6](#6-art-and-sound-from-the-asset-library)).

---

## 4. Make it your game

Write what you'd write in Roblox, in TypeScript. Everything comes from one import, `../framework/index`, and the services come in as arguments:

```ts
// server/game/place.ts
import { Color3, Enum, Instance, Vector3, type BasePart, type EnginePlace, type IntValue } from "../framework/index"

export const place: EnginePlace = ({ Workspace, Players, CollectionService }) => {
  // Coins on the ground: touch one to collect it.
  for (let i = 0; i < 5; i++) {
    const coin = new Instance("Part")
    coin.Name = "Coin"
    coin.Shape = Enum.PartType.Cylinder
    coin.Size = new Vector3(0.4, 3, 3)
    coin.Position = new Vector3(i * 8 - 16, 2, -20)
    coin.Color = Color3.fromRGB(255, 200, 40)
    coin.Material = Enum.Material.Neon
    coin.Anchored = true
    coin.CanCollide = false
    coin.AddTag("Coin")
    coin.Parent = Workspace
  }
  Players.PlayerAdded.Connect((player) => {
    const stats = new Instance("Folder")
    stats.Name = "leaderstats" // shown in the player list
    new Instance("IntValue", stats).Name = "Coins"
    stats.Parent = player
  })
  for (const coin of CollectionService.GetTagged("Coin") as BasePart[]) {
    coin.Touched.Connect((hit) => {
      const player = Players.GetPlayerFromCharacter(hit.Parent)
      const coins = player?.FindFirstChild("leaderstats")?.FindFirstChild("Coins") as IntValue | undefined
      if (!coins || !coin.Parent) return
      coins.Value += 1
      coin.Destroy()
    })
  }
}
```

- **Server and client:** `place.ts` decides what happens. `client.ts` shows it and sends input. A client asks the server through a RemoteEvent, and the server checks the request (range, cooldown, cost): anything a client sends is a claim.
- **Where the differences from Roblox are:**
  - `new Instance("Part")`, not `Instance.new`.
  - Methods with a dot: `part.Touched.Connect(fn)`.
  - Vector maths with methods: `a.add(b)`, `cf.mul(cf2)`.
  - Yielding with `await`: `await task.wait(1)`, `await store.GetAsync(key)`.
  - ENGINE.md has the full table.
- **Tests:** `server/game/tests.ts` plays the game on a test server with players whose clients run your client script (`testGame`). Keep the starter game's tests passing, and add one for each rule your game adds. ENGINE.md's "Testing" section shows how.

---

## 5. Check, push and play

```bash
sitemills-cli check      # compile, fast; saves nothing
sitemills-cli push       # upload, compile, run the game's tests, and update the preview
sitemills-cli deploy     # publish it at your site address
```

- **Play the preview:** `game create` and `push` print its link.
  - Everyone who opens it plays together in one room. Open it in two browser windows to see both players.
  - Add `solo` to the link's query (`&solo`, or `?solo` on a link without one) to play alone in the page, with no room.
  - Add `debug` the same way to put the game's view on `window.__game` for the browser's console: `__game.localPlayer`, `__game.engine`.
- **Phones:** touch controls are built in: a thumbstick, a jump button, a hotbar for tools and a button for prompts. Try the preview on a phone.
- **Tests on push:** push runs the game's tests and prints any that fail, with why. Treat a failing test as a bug in the game or the test.

---

## 6. Art and sound from the asset library

```bash
sitemills-cli game-assets search tree --kind MODEL
sitemills-cli game-assets search knight animated --kind MODEL
sitemills-cli game-assets search laser --kind SOUND --limit 5
sitemills-cli game-assets kits
```

On the engine, a library file's `url` goes straight into the instance that shows or plays it:

| Asset | On the engine | The reference |
|---|---|---|
| `MODEL` | A `MeshPart` with `MeshId = url`. The model is fitted inside the part's `Size`, keeping its proportions, and collides as that box. | `docs/world.md` |
| Animated `MODEL` (it lists `animations`) | `modelCharacter(name, url, { idle, walk, run, jump, die })` with the model's own clip names: an NPC, or every player's look as `StarterCharacter`. | `docs/world.md`, `docs/animation.md` |
| `SOUND` | A `Sound` in a part (heard from there) or in Workspace (heard everywhere): `sound.SoundId = url`, then `sound.Play()`. | ENGINE.md, "Sounds, teams, name tags" |
| `IMAGE` | A `Decal` or `Texture` on a part's face (`Texture = url`), or a GUI's `ImageLabel` (`Image = url`). | `docs/effects.md`, `docs/gui.md` |

- **Use the URLs as they are.** Library files load on SiteMills sites only: your app's address, its previews and its custom domains. Don't download and re-host them: many models load their textures from the folder next to them.
- **Keep the art matching:** search inside one pack with `--pack <pack>` (a result's `pack`).
- **Kits** are hand-picked sets for a genre. The 3D kits list their models for React Three Fiber, but the same `url`s and `clips` work on the engine as above. `sitemills-cli game-assets kit <id>` shows one.
- **Limits:** every `game-assets` request counts toward your account's Developer API limit (currently 60 a minute), and searches have their own daily allowance (currently 500 a day). When you hit one, the CLI says how long to wait.
- **License:** everything in the library is CC0 1.0: free to use in any project, no attribution required.

---

## 7. Rooms, saving and limits

- **Rooms:**
  - Everyone who opens the game joins a room of up to 16 players.
  - The room runs the game's server: `place.ts` and its physics at 60 steps a second.
  - It sends each player what changed 20 times a second.
- **Saving:**
  - `DataStoreService` keeps data between visits, per key: `GetAsync`, `SetAsync`, `UpdateAsync`, and ordered stores for leaderboards.
  - When the platform restarts a room's server (a deploy), players move to a fresh one and keep what the game saved.
- **What fits:** a few thousand parts, about 400 walking NPCs at once (600 at most), and 15 collision groups. Prefer large parts to many small ones.
- **Not here yet:** gamepads, swimming, collision shaped like a model, and animations from Roblox's library (`rbxassetid://`). ENGINE.md's "Limits" section has the full list for your version.

---

## 8. 2D games with Phaser

Phaser games run in an ordinary SiteMills React project (`sitemills-cli seed "My Game" ./my-game` makes one). `phaser`, `howler` and `zustand` are in the React stack's build, so there's nothing to install. Online play and saved data come from the platform's realtime and storage integrations, not from the engine.

```bash
sitemills-cli game-assets kit platformer --write src/game/assets.ts
```

That writes the kit's assets as `GAME_ASSETS`. Import it with `import { GAME_ASSETS } from "@/game/assets"`. Library files are on another origin, so the game config sets `loader: { crossOrigin: "anonymous" }`:

```ts
// src/game/config.ts
import Phaser from "phaser"
import { Play } from "./scenes/Play"
import { Preloader } from "./scenes/Preloader"

export const gameConfig: Phaser.Types.Core.GameConfig = {
  type: Phaser.AUTO,
  width: 800,
  height: 600,
  loader: { crossOrigin: "anonymous" }, // game asset library files are on another origin
  physics: { default: "arcade", arcade: { gravity: { x: 0, y: 700 } } },
  scale: { mode: Phaser.Scale.FIT, autoCenter: Phaser.Scale.CENTER_BOTH },
  scene: [Preloader, Play],
}
```

```ts
// src/game/scenes/Preloader.ts
import Phaser from "phaser"
import { GAME_ASSETS } from "@/game/assets"

export class Preloader extends Phaser.Scene {
  constructor() {
    super("Preloader")
  }

  preload() {
    this.load.image("player", GAME_ASSETS.player.idle.url)
    this.load.audio("jump", GAME_ASSETS.sounds.jump.url)
  }

  create() {
    this.scene.start("Play")
  }
}
```

```ts
// src/game/scenes/Play.ts
import Phaser from "phaser"

export class Play extends Phaser.Scene {
  private player!: Phaser.Types.Physics.Arcade.SpriteWithDynamicBody
  private keys!: Phaser.Types.Input.Keyboard.CursorKeys

  constructor() {
    super("Play")
  }

  create() {
    const ground = this.add.rectangle(400, 584, 800, 32, 0x334155)
    this.physics.add.existing(ground, true)
    // The platformer kit's characters are 128x128: half size suits its 64x64 tiles.
    this.player = this.physics.add.sprite(100, 450, "player").setScale(0.5).setCollideWorldBounds(true)
    this.physics.add.collider(this.player, ground)
    this.keys = this.input.keyboard!.createCursorKeys()
    this.input.on("pointerdown", () => this.jump()) // touch: tap to jump
  }

  update() {
    this.player.setVelocityX(this.keys.left.isDown ? -220 : this.keys.right.isDown ? 220 : 0)
    if (this.keys.up.isDown) this.jump()
  }

  private jump() {
    if (!this.player.body.blocked.down) return
    this.player.setVelocityY(-430)
    this.sound.play("jump")
  }
}
```

Mount the game once per page, and destroy it when the page unmounts:

```tsx
// src/game/PhaserGame.tsx
import { useEffect, useRef } from "react"
import Phaser from "phaser"

/** Mounts a Phaser game. Pass a config defined at module level: a new object restarts the game. */
export function PhaserGame({ config }: { config: Phaser.Types.Core.GameConfig }) {
  const host = useRef<HTMLDivElement>(null)
  useEffect(() => {
    if (!host.current) return
    const game = new Phaser.Game({ ...config, parent: host.current })
    return () => game.destroy(true)
  }, [config])
  return <div ref={host} className="h-full w-full" />
}
```

- **Load by kind:**
  - `IMAGE`: `this.load.image(key, url)`.
  - `SPRITESHEET`: `this.load.atlasXML(key, url, atlasUrl)`, or `this.load.atlas` when the atlas is `.json`.
  - `SOUND`: `this.load.audio(key, url)`.
- **Its own page:** give the game a route loaded with `lazy()` in `src/App.tsx`. Phaser is about 330 KB gzipped, so it belongs only on that page.
- **Size and input:** render `<PhaserGame config={gameConfig} />` inside an element with a height. Map taps or on-screen buttons to the same actions as the keys, for phones.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `game create` says the folder already exists | Give another folder after the name: `sitemills-cli game create "Kart Party" ./karts --template racing`. |
| A push is refused because of a file in `server/framework/` or `src/framework/` | Those are the engine's. Undo your change to them, or export the app into a fresh folder, and make the change in `server/game/`. |
| A push is refused because of `sitemills.json` | It can't change by push. Undo your change to it. |
| The game shows an error instead of loading | Read it in the browser's console. Add `&solo` to the link to rule out the room. Run `sitemills-cli check` for compile errors. |
| A test fails on push | Push prints which and why. Run the game with `&solo&debug` to see the same thing, and fix the game or the test. |
| A model is white or has no colours | Load it from its library `url` exactly as given: it reads its textures from the folder next to it. |
| An asset loads on your SiteMills site but not elsewhere | Library files load on SiteMills sites only: your app's address, its previews and its custom domains. |
| A character's animation doesn't play | Use the clip names from the kit's `clips` or the search result's `animations`: names differ between packs. |
| Phaser shows a black box or a missing-texture square | Set `loader: { crossOrigin: "anonymous" }` in the game config, and load the `url` exactly as given. |
| `Too many game asset requests` | Wait as long as the CLI says. Keep the assets you've found in your game's code instead of searching again. |
