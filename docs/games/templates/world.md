# Starter game: Open world

A town to walk and drive around: coins to collect (kept between visits), a car anyone can drive, a shop with a prompt that sells speed, and townsfolk walking between places.

Template `world`, on SiteMills game framework 1.0 (release 1.0.0). [The Games Guide](../../GAMES_GUIDE.md) says how to make it your game.

## Start from it

With the CLI, in one step:

```bash
sitemills-cli game create "My Game" --template world
```

Or by hand, from the files on this page:

1. Write each file below at its path, in an empty folder.
2. Import the folder as a new app: `sitemills-cli import "My Game" <folder>`.
3. Export it back into the folder: `sitemills-cli export <projectId> <folder>`. That adds the engine (`server/framework/`, `src/framework/`) and its reference, `server/framework/ENGINE.md`.

The engine isn't on this page: `sitemills.json` pins game framework 1.0, and the platform supplies it to every build.

## Files

### `index.html`

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
  <title>My Game</title>
  <!-- SiteMills platform clients (served by the platform): window.auth, metrics -->
  <script src="/metrics-client.js"></script>
  <script src="/auth-client.js"></script>
  <link rel="icon" type="image/svg+xml" href="/assets/images/favicon/app-logo.svg">
</head>
<body>
  <div id="root"></div>
  <!-- The game. The platform build replaces this with the bundled, hashed script. -->
  <script type="module" src="/src/main.tsx"></script>
</body>
</html>
```

### `public/assets/images/favicon/app-logo.svg`

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" fill="none">
  <defs>
    <!-- Crisp Light Squircle Background Gradient -->
    <linearGradient id="smBgGrad" x1="0" y1="0" x2="512" y2="512" gradientUnits="userSpaceOnUse">
      <stop offset="0%" stop-color="#ffffff"/>
      <stop offset="100%" stop-color="#f0f9ff"/>
    </linearGradient>

    <!-- Soft Sky Ambient Glow -->
    <radialGradient id="smGlow" cx="50%" cy="48%" r="52%">
      <stop offset="0%" stop-color="#0ea5e9" stop-opacity="0.10"/>
      <stop offset="70%" stop-color="#38bdf8" stop-opacity="0.03"/>
      <stop offset="100%" stop-color="#ffffff" stop-opacity="0"/>
    </radialGradient>

    <!-- Subtle Light-Theme Squircle Border -->
    <linearGradient id="smBorderGrad" x1="0" y1="0" x2="512" y2="512" gradientUnits="userSpaceOnUse">
      <stop offset="0%" stop-color="#7dd3fc" stop-opacity="0.65"/>
      <stop offset="50%" stop-color="#cbd5e1" stop-opacity="0.55"/>
      <stop offset="100%" stop-color="#38bdf8" stop-opacity="0.45"/>
    </linearGradient>

    <!-- SiteMills Horizontal Arch Gradient -->
    <linearGradient id="smArchGrad" x1="128" y1="751" x2="892" y2="751" gradientUnits="userSpaceOnUse">
      <stop offset="0%" stop-color="#0284c7" />
      <stop offset="30%" stop-color="#0ea5e9" />
      <stop offset="50%" stop-color="#0284c7" />
      <stop offset="70%" stop-color="#0ea5e9" />
      <stop offset="100%" stop-color="#0284c7" />
    </linearGradient>

    <!-- SiteMills Upward Crossing Ribbon Gradient -->
    <linearGradient id="smUpGrad" x1="330" y1="791" x2="695" y2="195" gradientUnits="userSpaceOnUse">
      <stop offset="0%" stop-color="#0ea5e9" />
      <stop offset="40%" stop-color="#0284c7" />
      <stop offset="55%" stop-color="#0369a1" />
      <stop offset="80%" stop-color="#0ea5e9" />
      <stop offset="100%" stop-color="#38bdf8" />
    </linearGradient>

    <!-- Crossing Ribbon Depth Shadow -->
    <filter id="smRibbonShadow" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="-2" dy="4" stdDeviation="5" flood-color="#022040" flood-opacity="0.22" />
    </filter>
  </defs>

  <!-- Light Squircle Background -->
  <rect x="4" y="4" width="504" height="504" rx="124" fill="url(#smBgGrad)"/>
  <rect x="4" y="4" width="504" height="504" rx="124" fill="url(#smGlow)"/>
  <!-- Crisp Border Highlight -->
  <rect x="4" y="4" width="504" height="504" rx="124" fill="none" stroke="url(#smBorderGrad)" stroke-width="8"/>

  <!-- SiteMills Brand Mark -->
  <g transform="translate(256, 256) scale(0.44) translate(-510, -493)">
    <!-- Base Horizontal Arch -->
    <path
      d="M 128 751 C 220 588, 403 511, 510 492 C 617 511, 800 588, 892 751"
      stroke="url(#smArchGrad)"
      stroke-width="76"
      stroke-linecap="round"
      stroke-linejoin="round"
    />

    <!-- Upward Crossing Ribbon with Depth Shadow -->
    <path
      d="M 330 791 C 421 739, 488 631, 514 489 C 540 361, 608 261, 695 195"
      stroke="url(#smUpGrad)"
      stroke-width="76"
      stroke-linecap="round"
      stroke-linejoin="round"
      filter="url(#smRibbonShadow)"
    />
  </g>
</svg>
```

### `server/game/client.ts`

```ts
// The game's client script (Roblox's LocalScripts): it runs in each player's page once their player is known. Here it
// keeps the HUD's coin count up to date (the HUD is copied afresh from StarterGui each time the character spawns).
import type { ClientScript, IntValue, TextLabel } from "../framework/index"

export const client: ClientScript = ({ player, RunService }) => {
  RunService.RenderStepped.Connect(() => {
    const label = player.PlayerGui?.FindFirstChild("Hud")?.FindFirstChild("Coins") as TextLabel | undefined
    const coins = player.FindFirstChild("leaderstats")?.FindFirstChild("Coins") as IntValue | undefined
    if (label) label.Text = `Coins: ${coins?.Value ?? 0}`
  })
}
```

### `server/game/place.ts`

```ts
// Open world: a sunlit town to walk and drive around. Coins to collect (kept between visits in a DataStore), a sports
// car anyone can drive (a car of the engine's own: a VehicleSeat and four VehicleWheels), a market stall with a
// ProximityPrompt that sells speed, and townsfolk walking between places along paths (PathfindingService).
import {
  CFrame,
  Color3,
  Enum,
  Instance,
  UDim,
  UDim2,
  Vector3,
  modelCharacter,
  type BasePart,
  type EnginePlace,
  type GameShellConfig,
  type Humanoid,
  type IntValue,
} from "../framework/index"

const PLAYER_URL = "https://game-assets.sitemills.com/library/quaternius/ultimate-platformer-pack/9de203bd37df/Character/glTF/Character.glb"
const CITIZEN_URL = "https://game-assets.sitemills.com/library/kenney/mini-dungeon/0b0b44e6d2bc/Models/GLB-format/character-human.glb"
const HOUSE_A_URL = "https://game-assets.sitemills.com/library/kenney/city-kit-suburban/61b19bfc1b12/Models/GLB-format/building-type-a.glb"
const HOUSE_B_URL = "https://game-assets.sitemills.com/library/kenney/city-kit-suburban/61b19bfc1b12/Models/GLB-format/building-type-c.glb"
const COTTAGE_URL = "https://game-assets.sitemills.com/library/kenney/city-kit-suburban/61b19bfc1b12/Models/GLB-format/building-type-g.glb"
const SHOP_BLDG_URL = "https://game-assets.sitemills.com/library/kenney/city-kit-commercial/b3824e616b62/Models/GLB-format/building-c.glb"
const STALL_URL = "https://game-assets.sitemills.com/library/kenney/fantasy-town-kit/d842ff2cf531/Models/GLB-format/stall-red.glb"
const FOUNTAIN_URL = "https://game-assets.sitemills.com/library/kenney/fantasy-town-kit/d842ff2cf531/Models/GLB-format/fountain-round.glb"
const SPORTS_CAR_URL = "https://game-assets.sitemills.com/library/kenney/car-kit/13fdbc4bf754/Models/GLB-format/sedan-sports.glb"
const PARK_TREE_URL = "https://game-assets.sitemills.com/library/kenney/city-kit-suburban/61b19bfc1b12/Models/GLB-format/tree-large.glb"
const STREET_LIGHT_URL = "https://game-assets.sitemills.com/library/kenney/city-kit-roads/b142988f78f7/Models/GLB-format/light-curved.glb"
const COIN_URL = "https://game-assets.sitemills.com/library/quaternius/ultimate-platformer-pack/9de203bd37df/Powerups-and-Pickups/glTF/Coin.glb"
const COIN_SOUND_URL = "https://game-assets.sitemills.com/library/kenney/rpg-audio/367ea9e4cb91/Audio/handleCoins.ogg"
const BUY_SOUND_URL = "https://game-assets.sitemills.com/library/kenney/digital-audio/d5e67cad8eea/Audio/powerUp2.ogg"

export const shell: GameShellConfig = {
  title: "Sunlit Harbor Town",
  subtitle: "Stroll tree-lined avenues, gather spinning gold coins, buy speed boots at the market stall, and cruise in the town sports car.",
  modes: [
    {
      id: "explore",
      name: "Town Life",
      description: "Open-world town hangout for 1–16 players.",
      minPlayers: 1,
      maxPlayers: 16,
    },
  ],
  howToPlay: [
    "Walk with WASD or the thumbstick to collect gold coins saved across visits.",
    "Visit the red market stall with 10 coins for a speed boost, or hop into the sports car's driver seat to cruise the avenues.",
  ],
  controls: [
    { keys: "WASD", action: "Walk / Drive" },
    { keys: "Space", action: "Jump / Exit car" },
    { keys: "Drag Mouse", action: "Orbit camera" },
    { keys: "E", action: "Interact at market stall" },
    { keys: "M", action: "Expand town map" },
    { keys: "Enter or /", action: "Chat" },
    { keys: "Esc", action: "Pause & Settings" },
  ],
  minimap: { range: 160, players: "all" },
}

export const place: EnginePlace = ({
  Workspace,
  Lighting,
  Players,
  StarterPlayer,
  StarterGui,
  RunService,
  DataStoreService,
  PathfindingService,
  task,
}) => {
  Lighting.ClockTime = 15.5
  new Instance("Sky", Lighting)

  const avatar = modelCharacter("StarterCharacter", PLAYER_URL, {
    idle: "Idle",
    walk: "Walk",
    run: "Run",
    jump: "Jump",
    fall: "Jump_Idle",
    die: "Death",
    wave: "Wave",
  })
  avatar.Parent = StarterPlayer

  const part = (name: string, size: Vector3, at: Vector3, color: Color3, material = Enum.Material.SmoothPlastic, parent: Instance = Workspace) => {
    const p = new Instance("Part")
    p.Name = name
    p.Anchored = true
    p.Size = size
    p.Position = at
    p.Color = color
    p.Material = material
    p.Parent = parent
    return p
  }
  const meshProp = (name: string, meshId: string, size: Vector3, cf: CFrame, collide = true) => {
    const m = new Instance("MeshPart")
    m.Name = name
    m.MeshId = meshId
    m.Anchored = true
    m.CanCollide = collide
    if (!collide) {
      m.CanTouch = false
      m.CanQuery = false
    }
    m.Size = size
    m.CFrame = cf
    m.Parent = Workspace
    return m
  }

  // Lawn, crossing asphalt avenues, cobblestone central square, fountain, houses, trees, and street lamps.
  part("Grass", new Vector3(400, 2, 400), new Vector3(0, -1, 0), Color3.fromRGB(98, 152, 74), Enum.Material.Grass)
  part("RoadNS", new Vector3(24, 0.2, 400), new Vector3(0, 0.1, 0), Color3.fromRGB(64, 66, 72), Enum.Material.Asphalt)
  part("RoadEW", new Vector3(400, 0.2, 24), new Vector3(0, 0.12, 0), Color3.fromRGB(64, 66, 72), Enum.Material.Asphalt)
  part("Square", new Vector3(32, 0.22, 32), new Vector3(0, 0.14, 0), Color3.fromRGB(178, 170, 158), Enum.Material.Cobblestone)
  meshProp("TownFountain", FOUNTAIN_URL, new Vector3(13, 2.2, 13), new CFrame(0, 1.25, 0))

  const homeSpecs = [
    { url: HOUSE_A_URL, size: new Vector3(26, 20, 22) },
    { url: SHOP_BLDG_URL, size: new Vector3(21.2, 21.4, 24) },
    { url: HOUSE_B_URL, size: new Vector3(26, 24.8, 22) },
    { url: COTTAGE_URL, size: new Vector3(28, 18.4, 24) },
  ]
  let n = 0
  for (const x of [-64, -32, 32, 64]) {
    for (const z of [-64, 64]) {
      const spec = homeSpecs[n % homeSpecs.length]
      const yaw = z < 0 ? 0 : Math.PI
      meshProp(`House${++n}`, spec.url, spec.size, new CFrame(x, spec.size.Y / 2, z).mul(CFrame.Angles(0, yaw, 0)))
    }
  }
  for (const [tx, tz] of [[-52, -26], [-28, 30], [32, 30], [54, -26], [-78, -28], [78, 28]] as const) {
    meshProp("ParkTree", PARK_TREE_URL, new Vector3(4.5, 15.5, 4.9), new CFrame(tx, 7.75, tz))
  }
  for (const [lx, lz, yaw] of [[-14, -36, 0], [14, -36, Math.PI], [-14, 36, 0], [14, 36, Math.PI]] as const) {
    meshProp("StreetLamp", STREET_LIGHT_URL, new Vector3(1, 12.2, 4.1), new CFrame(lx, 6.1, lz).mul(CFrame.Angles(0, yaw, 0)), false)
  }

  const spawn = new Instance("SpawnLocation")
  spawn.Size = new Vector3(10, 0.6, 10)
  spawn.Position = new Vector3(-20, 0.3, -20)
  spawn.Color = Color3.fromRGB(205, 198, 184)
  spawn.Material = Enum.Material.Marble
  spawn.Parent = Workspace

  const coinSound = new Instance("Sound", Workspace)
  coinSound.Name = "CoinPickup"
  coinSound.SoundId = COIN_SOUND_URL
  const buySound = new Instance("Sound", Workspace)
  buySound.Name = "BuySpeed"
  buySound.SoundId = BUY_SOUND_URL

  // Coins: each player's count is in leaderstats, and kept in a DataStore by their UserId.
  const saves = DataStoreService.GetDataStore("Coins")
  Players.PlayerAdded.Connect(async (player) => {
    const stats = new Instance("Folder")
    stats.Name = "leaderstats"
    const coins = new Instance("IntValue", stats)
    coins.Name = "Coins"
    stats.Parent = player
    coins.Value = ((await saves.GetAsync(String(player.UserId))) as number | undefined) ?? 0
  })
  Players.PlayerRemoving.Connect((player) => {
    const coins = player.FindFirstChild("leaderstats")?.FindFirstChild("Coins") as IntValue | undefined
    if (coins) void saves.SetAsync(String(player.UserId), coins.Value)
  })
  const spinning = new Set<BasePart>()
  const coinAt = (at: Vector3) => {
    const coin = new Instance("MeshPart")
    coin.Name = "Coin"
    coin.MeshId = COIN_URL
    coin.Anchored = true
    coin.CanCollide = false
    coin.Size = new Vector3(2.8, 2.8, 1.2)
    coin.CFrame = new CFrame(at.X, at.Y, at.Z)
    coin.Parent = Workspace
    spinning.add(coin)
    coin.Touched.Connect((hit) => {
      const player = Players.GetPlayerFromCharacter(hit.Parent)
      const coins = player?.FindFirstChild("leaderstats")?.FindFirstChild("Coins") as IntValue | undefined
      if (!coins || !coin.Parent) return
      coins.Value += 1
      coinSound.Play()
      coin.Destroy()
      task.delay(5, () => coinAt(new Vector3((Math.random() - 0.5) * 160, 2.5, (Math.random() - 0.5) * 160)))
    })
  }
  RunService.Heartbeat.Connect((dt) => {
    for (const coin of spinning) {
      if (!coin.Parent) spinning.delete(coin)
      else coin.CFrame = coin.CFrame.mul(CFrame.Angles(0, dt * 2, 0))
    }
  })
  for (let i = 0; i < 12; i++) coinAt(new Vector3((i % 4) * 14 - 21, 2.5, Math.floor(i / 4) * 14 - 40))

  // The shop: a market stall with a ProximityPrompt. 10 coins buy speed.
  const shop = part("Shop", new Vector3(8, 4, 4), new Vector3(20, 2, -20), Color3.fromRGB(145, 98, 62), Enum.Material.WoodPlanks)
  shop.Transparency = 1
  meshProp("MarketStall", STALL_URL, new Vector3(8, 9.9, 8), new CFrame(20, 4.95, -20), false)
  const prompt = new Instance("ProximityPrompt", shop)
  prompt.ActionText = "Buy speed"
  prompt.ObjectText = "10 coins"
  prompt.Triggered.Connect((player) => {
    const coins = player.FindFirstChild("leaderstats")?.FindFirstChild("Coins") as IntValue | undefined
    const humanoid = player.Character?.FindFirstChildOfClass("Humanoid") as Humanoid | undefined
    if (!coins || !humanoid || coins.Value < 10) return
    coins.Value -= 10
    humanoid.WalkSpeed = 26
    buySound.Play()
  })

  // A sports car: an invisible chassis, a VehicleSeat, four invisible wheels that carry it (VehicleWheels), and a 3D
  // car body welded on. The engine drives it: whoever sits in the seat drives.
  const car = new Instance("Model")
  car.Name = "Car"
  const chassis = part("Chassis", new Vector3(5.4, 1, 10), new Vector3(-3.5, 3, 28), Color3.fromRGB(36, 38, 44), Enum.Material.SmoothPlastic, car)
  chassis.Anchored = false
  chassis.Transparency = 1
  const carBody = new Instance("MeshPart")
  carBody.Name = "Body"
  carBody.MeshId = SPORTS_CAR_URL
  carBody.Size = new Vector3(5.2, 4.4, 10.2)
  carBody.CanCollide = false
  carBody.CanQuery = false
  carBody.CanTouch = false
  carBody.Massless = true
  carBody.CFrame = chassis.CFrame.mul(new CFrame(0, 0.7, 0)).mul(CFrame.Angles(0, Math.PI, 0))
  carBody.Parent = car
  const bodyWeld = new Instance("WeldConstraint", carBody)
  bodyWeld.Part0 = chassis
  bodyWeld.Part1 = carBody
  const seat = new Instance("VehicleSeat")
  seat.Position = new Vector3(-3.5, 3.6, 28.4)
  seat.Transparency = 1
  seat.MaxSpeed = 60
  seat.Parent = car
  const weld = new Instance("WeldConstraint", seat)
  weld.Part0 = chassis
  weld.Part1 = seat
  // The front (the seat's look, -Z) steers.
  for (const [x, z] of [[-3.2, -3], [3.2, -3], [-3.2, 3], [3.2, 3]]) {
    const wheel = new Instance("Part")
    wheel.Name = "Wheel"
    wheel.Shape = Enum.PartType.Cylinder
    wheel.Size = new Vector3(0.9, 2.8, 2.8)
    wheel.Position = new Vector3(-3.5 + x, 2, 28 + z)
    wheel.Transparency = 1
    wheel.Parent = car
    const spec = new Instance("VehicleWheel")
    spec.Steer = z < 0
    spec.Parent = wheel
    const axle = new Instance("WeldConstraint", wheel)
    axle.Part0 = chassis
    axle.Part1 = wheel
  }
  car.Parent = Workspace

  // Townsfolk: animated 3D citizens strolling round the town square.
  const places = [new Vector3(-40, 0, -40), new Vector3(40, 0, -40), new Vector3(40, 0, 40), new Vector3(-40, 0, 40)]
  for (let i = 0; i < 2; i++) {
    const walker = modelCharacter(`Townsperson${i + 1}`, CITIZEN_URL, {
      idle: "idle",
      walk: "walk",
      run: "sprint",
      jump: "jump",
      fall: "fall",
      die: "die",
      wave: "emote-yes",
    })
    walker.PivotTo(new CFrame(places[i].X, 4, places[i].Z))
    walker.Parent = Workspace
    const humanoid = walker.FindFirstChildOfClass("Humanoid") as Humanoid
    humanoid.WalkSpeed = 8
    task.spawn(async () => {
      let next = i + 1
      while (walker.Parent) {
        const root = walker.FindFirstChild("HumanoidRootPart") as BasePart
        const path = PathfindingService.CreatePath({ AgentRadius: 2 })
        await path.ComputeAsync(root.Position, places[next % places.length])
        for (const waypoint of path.Status === Enum.PathStatus.Success ? path.GetWaypoints() : []) {
          if (waypoint.Action === Enum.PathWaypointAction.Jump) humanoid.Jump = true
          humanoid.MoveTo(waypoint.Position)
          await new Promise<void>((done) => {
            const c = humanoid.MoveToFinished.Connect(() => {
              c.Disconnect()
              done()
            })
          })
        }
        next++
        await task.wait(2)
      }
    })
  }

  // The HUD (each player's copy is made from StarterGui; the client script keeps it up to date).
  const hud = new Instance("ScreenGui")
  hud.Name = "Hud"
  const label = new Instance("TextLabel", hud)
  label.Name = "Coins"
  label.Size = UDim2.fromOffset(170, 44)
  label.Position = UDim2.fromOffset(16, 16)
  label.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
  label.BackgroundTransparency = 0.25
  label.BorderSizePixel = 0
  label.TextColor3 = Color3.fromRGB(255, 215, 80)
  label.Font = Enum.Font.GothamBold
  label.TextSize = 22
  label.Text = "Coins: 0"
  new Instance("UICorner", label).CornerRadius = new UDim(0, 12)
  hud.Parent = StarterGui
}
```

### `server/game/tests.ts`

```ts
// The game's own tests: they run on every build. testGame plays the place on a test server, and each player who joins
// is a client running the game's client script, as their page does. Time passes with `await t.wait(seconds)`.
import { describe, expect, test } from "../../api/test-framework.js"
import { CFrame, Vector3, testGame, type BasePart, type Humanoid, type IntValue, type Model, type ProximityPrompt, type TextLabel } from "../framework/index"
import { client } from "./client"
import { place } from "./place"

describe("the town", () => {
  test("a coin gives a coin, the HUD shows it, and the shop sells speed for 10", async () => {
    const t = await testGame(place, { client })
    const ana = t.join("Ana")
    await t.wait(1)
    const character = ana.serverPlayer.Character as Model
    const coins = ana.serverPlayer.FindFirstChild("leaderstats")?.FindFirstChild("Coins") as IntValue
    // Put Ana on a coin (on the server, as a script would move her).
    const coin = t.services.Workspace.FindFirstChild("Coin") as BasePart
    character.PivotTo(new CFrame(coin.Position))
    await t.wait(0.5)
    expect(coins.Value).toBe(1)
    const label = ana.player?.FindFirstChild("PlayerGui")?.FindFirstChild("Hud")?.FindFirstChild("Coins") as TextLabel
    expect(label.Text).toBe("Coins: 1")
    // At the shop with 10 coins, its prompt makes her faster.
    coins.Value = 10
    const shop = t.services.Workspace.FindFirstChild("Shop") as BasePart
    character.PivotTo(new CFrame(shop.Position.add(new Vector3(0, 1, 5))))
    await t.wait(0.5)
    ana.prompt(shop.FindFirstChildOfClass("ProximityPrompt") as ProximityPrompt)
    await t.wait(0.5)
    expect((character.FindFirstChildOfClass("Humanoid") as Humanoid).WalkSpeed).toBe(26)
    expect(coins.Value).toBe(0)
  })

  test("a player's coins are kept for their next visit", async () => {
    const t = await testGame(place, { client })
    const ana = t.join("Ana", 7)
    await t.wait(0.5)
    const coins = () => ana.serverPlayer.FindFirstChild("leaderstats")?.FindFirstChild("Coins") as IntValue
    coins().Value = 4
    ana.leave()
    await t.wait(0.5)
    const back = t.join("Ana", 7)
    await t.wait(0.5)
    expect((back.serverPlayer.FindFirstChild("leaderstats")?.FindFirstChild("Coins") as IntValue).Value).toBe(4)
  })
})
```

### `server/rooms/game_room.ts`

```ts
import { engineRoom, type GameShellConfig } from "../framework/index"
import * as gamePlace from "../game/place"

// The game's server: a room runs the place, and each player who opens the page joins it.
const { place, shell } = gamePlace as typeof gamePlace & { shell?: GameShellConfig }
sdk.registerRoom("game", engineRoom(place, { maxPlayers: 16, shell }))
```

### `sitemills.json`

```json
{
  "schemaVersion": 1,
  "stack": "react-bundled-v1",
  "gameFramework": "1.0"
}
```

### `src/App.tsx`

```tsx
import { lazy, Suspense } from "react"
import { Route, Routes } from "react-router"

import { NotFoundPage } from "@/pages/NotFound"

// three.js and the physics are large, so the game loads as its own chunk.
const GamePage = lazy(() => import("@/pages/Game").then((module) => ({ default: module.GamePage })))

export function App() {
  return (
    <Suspense fallback={<div className="h-svh w-full bg-black" />}>
      <Routes>
        <Route path="/" element={<GamePage />} />
        <Route path="*" element={<NotFoundPage />} />
      </Routes>
    </Suspense>
  )
}
```

### `src/components/ui/button.tsx`

```tsx
import * as React from "react"
import { cva, type VariantProps } from "class-variance-authority"
import { cn } from "@/lib/utils"
import { Slot } from "radix-ui"

const buttonVariants = cva(
  "inline-flex shrink-0 items-center justify-center gap-2 rounded-md text-sm font-medium whitespace-nowrap transition-all outline-none focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 disabled:pointer-events-none disabled:opacity-50 aria-invalid:border-destructive aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4",
  {
    variants: {
      variant: {
        default: "bg-primary text-primary-foreground hover:bg-primary/90",
        destructive:
          "bg-destructive text-white hover:bg-destructive/90 focus-visible:ring-destructive/20 dark:bg-destructive/60 dark:focus-visible:ring-destructive/40",
        outline:
          "border bg-background shadow-xs hover:bg-accent hover:text-accent-foreground dark:border-input dark:bg-input/30 dark:hover:bg-input/50",
        secondary:
          "bg-secondary text-secondary-foreground hover:bg-secondary/80",
        ghost:
          "hover:bg-accent hover:text-accent-foreground dark:hover:bg-accent/50",
        link: "text-primary underline-offset-4 hover:underline",
      },
      size: {
        default: "h-9 px-4 py-2 has-[>svg]:px-3",
        xs: "h-6 gap-1 rounded-md px-2 text-xs has-[>svg]:px-1.5 [&_svg:not([class*='size-'])]:size-3",
        sm: "h-8 gap-1.5 rounded-md px-3 has-[>svg]:px-2.5",
        lg: "h-10 rounded-md px-6 has-[>svg]:px-4",
        icon: "size-9",
        "icon-xs": "size-6 rounded-md [&_svg:not([class*='size-'])]:size-3",
        "icon-sm": "size-8",
        "icon-lg": "size-10",
      },
    },
    defaultVariants: {
      variant: "default",
      size: "default",
    },
  }
)

function Button({
  className,
  variant = "default",
  size = "default",
  asChild = false,
  ...props
}: React.ComponentProps<"button"> &
  VariantProps<typeof buttonVariants> & {
    asChild?: boolean
  }) {
  const Comp = asChild ? Slot.Root : "button"

  return (
    <Comp
      data-slot="button"
      data-variant={variant}
      data-size={size}
      className={cn(buttonVariants({ variant, size, className }))}
      {...props}
    />
  )
}

export { Button, buttonVariants }
```

### `src/index.css`

```css
@import "tailwindcss";
@import "tw-animate-css";
@import "shadcn/tailwind.css";

@custom-variant dark (&:is(.dark *));

/* Theme tokens (shadcn/ui, neutral). Change these to restyle every component at once. */
:root {
  --background: oklch(1 0 0);
  --foreground: oklch(0.145 0 0);
  --card: oklch(1 0 0);
  --card-foreground: oklch(0.145 0 0);
  --popover: oklch(1 0 0);
  --popover-foreground: oklch(0.145 0 0);
  --primary: oklch(0.205 0 0);
  --primary-foreground: oklch(0.985 0 0);
  --secondary: oklch(0.97 0 0);
  --secondary-foreground: oklch(0.205 0 0);
  --muted: oklch(0.97 0 0);
  --muted-foreground: oklch(0.556 0 0);
  --accent: oklch(0.97 0 0);
  --accent-foreground: oklch(0.205 0 0);
  --destructive: oklch(0.577 0.245 27.325);
  --border: oklch(0.922 0 0);
  --input: oklch(0.922 0 0);
  --ring: oklch(0.708 0 0);
  --chart-1: oklch(0.87 0 0);
  --chart-2: oklch(0.556 0 0);
  --chart-3: oklch(0.439 0 0);
  --chart-4: oklch(0.371 0 0);
  --chart-5: oklch(0.269 0 0);
  --radius: 0.625rem;
  --sidebar: oklch(0.985 0 0);
  --sidebar-foreground: oklch(0.145 0 0);
  --sidebar-primary: oklch(0.205 0 0);
  --sidebar-primary-foreground: oklch(0.985 0 0);
  --sidebar-accent: oklch(0.97 0 0);
  --sidebar-accent-foreground: oklch(0.205 0 0);
  --sidebar-border: oklch(0.922 0 0);
  --sidebar-ring: oklch(0.708 0 0);
}

.dark {
  --background: oklch(0.145 0 0);
  --foreground: oklch(0.985 0 0);
  --card: oklch(0.205 0 0);
  --card-foreground: oklch(0.985 0 0);
  --popover: oklch(0.205 0 0);
  --popover-foreground: oklch(0.985 0 0);
  --primary: oklch(0.922 0 0);
  --primary-foreground: oklch(0.205 0 0);
  --secondary: oklch(0.269 0 0);
  --secondary-foreground: oklch(0.985 0 0);
  --muted: oklch(0.269 0 0);
  --muted-foreground: oklch(0.708 0 0);
  --accent: oklch(0.269 0 0);
  --accent-foreground: oklch(0.985 0 0);
  --destructive: oklch(0.704 0.191 22.216);
  --border: oklch(1 0 0 / 10%);
  --input: oklch(1 0 0 / 15%);
  --ring: oklch(0.556 0 0);
  --chart-1: oklch(0.87 0 0);
  --chart-2: oklch(0.556 0 0);
  --chart-3: oklch(0.439 0 0);
  --chart-4: oklch(0.371 0 0);
  --chart-5: oklch(0.269 0 0);
  --sidebar: oklch(0.205 0 0);
  --sidebar-foreground: oklch(0.985 0 0);
  --sidebar-primary: oklch(0.488 0.243 264.376);
  --sidebar-primary-foreground: oklch(0.985 0 0);
  --sidebar-accent: oklch(0.269 0 0);
  --sidebar-accent-foreground: oklch(0.985 0 0);
  --sidebar-border: oklch(1 0 0 / 10%);
  --sidebar-ring: oklch(0.556 0 0);
}

@theme inline {
  --radius-sm: calc(var(--radius) - 4px);
  --radius-md: calc(var(--radius) - 2px);
  --radius-lg: var(--radius);
  --radius-xl: calc(var(--radius) + 4px);
  --color-background: var(--background);
  --color-foreground: var(--foreground);
  --color-card: var(--card);
  --color-card-foreground: var(--card-foreground);
  --color-popover: var(--popover);
  --color-popover-foreground: var(--popover-foreground);
  --color-primary: var(--primary);
  --color-primary-foreground: var(--primary-foreground);
  --color-secondary: var(--secondary);
  --color-secondary-foreground: var(--secondary-foreground);
  --color-muted: var(--muted);
  --color-muted-foreground: var(--muted-foreground);
  --color-accent: var(--accent);
  --color-accent-foreground: var(--accent-foreground);
  --color-destructive: var(--destructive);
  --color-border: var(--border);
  --color-input: var(--input);
  --color-ring: var(--ring);
  --color-chart-1: var(--chart-1);
  --color-chart-2: var(--chart-2);
  --color-chart-3: var(--chart-3);
  --color-chart-4: var(--chart-4);
  --color-chart-5: var(--chart-5);
  --color-sidebar: var(--sidebar);
  --color-sidebar-foreground: var(--sidebar-foreground);
  --color-sidebar-primary: var(--sidebar-primary);
  --color-sidebar-primary-foreground: var(--sidebar-primary-foreground);
  --color-sidebar-accent: var(--sidebar-accent);
  --color-sidebar-accent-foreground: var(--sidebar-accent-foreground);
  --color-sidebar-border: var(--sidebar-border);
  --color-sidebar-ring: var(--sidebar-ring);
}

@layer base {
  * {
    @apply border-border outline-ring/50;
  }
  body {
    @apply bg-background text-foreground antialiased;
  }
}
```

### `src/lib/utils.ts`

```ts
import { clsx, type ClassValue } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}
```

### `src/main.tsx`

```tsx
import { StrictMode } from "react"
import { createRoot } from "react-dom/client"
import { BrowserRouter } from "react-router"
import { QueryClient, QueryClientProvider } from "@tanstack/react-query"
import { Toaster } from "sonner"

import { App } from "@/App"
import "./index.css"

const queryClient = new QueryClient()

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        <App />
        <Toaster richColors position="top-right" />
      </BrowserRouter>
    </QueryClientProvider>
  </StrictMode>
)
```

### `src/pages/Game.tsx`

```tsx
import { useEffect, useRef, useState } from "react"
import RAPIER from "@dimforge/rapier3d-compat"
import { createRoom, joinRoom, joinRoomByCode, listRooms } from "@/api/room-client"
import { mountGameShell, type GameShellConfig } from "@/framework/index"
import { client } from "../../server/game/client"
import * as gamePlace from "../../server/game/place"

/**
 * The game page: opens on the game shell overlay (title screen, modes, server browser, private room codes, how to play,
 * and graphics/audio settings) backed by a live 3D preview. With `?solo` it plays alone in the page; with `?code=...`,
 * `?room=...`, or `?autojoin` it enters a room immediately. With `?debug`, `window.__game` exposes the active game view.
 */
export function GamePage() {
  const container = useRef<HTMLDivElement>(null)
  const canvas = useRef<HTMLCanvasElement>(null)
  const [booting, setBooting] = useState(true)
  const [problem, setProblem] = useState<string | null>(null)
  const shellConfig = (gamePlace as { shell?: GameShellConfig }).shell
  useEffect(() => {
    let dispose: (() => void) | null = null
    let gone = false
    void (async () => {
      await RAPIER.init()
      if (gone || !canvas.current || !container.current) return
      const shell = await mountGameShell({
        canvas: canvas.current,
        container: container.current,
        physics: RAPIER,
        place: gamePlace.place,
        client,
        shell: shellConfig,
        rooms: { joinRoom, listRooms, createRoom, joinRoomByCode },
        onError: (msg) => setProblem(msg),
        onGameChange: (g) => {
          if (g) setProblem(null)
        },
      })
      if (gone) shell.dispose()
      else {
        dispose = () => shell.dispose()
        setBooting(false)
      }
    })().catch((error: unknown) => {
      setBooting(false)
      setProblem(error instanceof Error ? error.message : String(error))
    })
    return () => {
      gone = true
      dispose?.()
    }
  }, [])
  return (
    <div ref={container} className="relative h-svh w-full select-none overflow-hidden bg-[#090d18]">
      <canvas ref={canvas} className="block h-full w-full" />
      {booting && !problem && (
        <div className="pointer-events-none absolute inset-0 z-40 flex flex-col items-center justify-center bg-[#090d18] px-6 text-center text-slate-100">
          <div className="w-full max-w-md rounded-2xl border border-slate-700/40 bg-slate-900/90 px-7 py-6 shadow-2xl">
            <h2 className="text-2xl font-extrabold tracking-tight">{shellConfig?.title || "Loading Game"}</h2>
            {shellConfig?.subtitle && <p className="mt-1.5 text-sm text-slate-400">{shellConfig.subtitle}</p>}
            <div className="mt-5 h-2 w-full overflow-hidden rounded-full bg-slate-700/40">
              <div className="h-full w-1/4 animate-pulse rounded-full bg-gradient-to-r from-sky-400 to-indigo-500" />
            </div>
            <p className="mt-3 text-xs font-medium text-slate-300">Initializing physics engine...</p>
          </div>
        </div>
      )}
      {problem && <div className="absolute inset-x-0 top-4 z-50 mx-auto w-fit max-w-[90%] rounded-lg bg-red-600 px-4 py-2 text-sm text-white">{problem}</div>}
    </div>
  )
}
```

### `src/pages/NotFound.tsx`

```tsx
import { Link } from "react-router"

import { Button } from "@/components/ui/button"

export function NotFoundPage() {
  return (
    <main className="flex min-h-svh flex-col items-center justify-center gap-4 p-6 text-center">
      <h1 className="text-4xl font-semibold tracking-tight">Page not found</h1>
      <p className="text-muted-foreground">The page you are looking for does not exist.</p>
      <Button asChild>
        <Link to="/">Go home</Link>
      </Button>
    </main>
  )
}
```
