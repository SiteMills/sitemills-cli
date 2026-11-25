# Starter game: Racing

A kart race on a ring road: each player starts in their own kart on the grid, a countdown, three laps, places as it goes, and each player's best lap kept between visits. Each kart is a car of the engine's own (a VehicleSeat and four VehicleWheels under a race car model: suspension, grip, gears, Shift for the handbrake), held on the grid until GO, and the server counts laps by gates passed in order. The start of any racing or driving game.

Template `racing`, on SiteMills game framework 1.0 (release 1.0.0). [The Games Guide](../../GAMES_GUIDE.md) says how to make it your game.

## Start from it

With the CLI, in one step:

```bash
sitemills-cli game create "My Game" --template racing
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
// The game's client script: the handbrake, the camera behind this player's kart, and the HUD.
// - The kart drives itself from its seat (a car of the engine's own): nothing here moves it. Shift is its handbrake
//   (the back swings round: a drift).
import { CFrame, Enum, Vector3, VehicleSeat, type BasePart, type ClientScript, type Model, type RemoteEvent, type TextButton, type TextLabel } from "../framework/index"
import { LAPS } from "./place"

export const client: ClientScript = ({ player, Workspace, ReplicatedStorage, RunService, UserInputService, CollectionService }) => {
  const camera = Workspace.CurrentCamera
  const reset = ReplicatedStorage.FindFirstChild("Reset") as RemoteEvent
  const myKart = () => CollectionService.GetTagged("Kart").find((k) => k.GetAttribute("Owner") === player.UserId) as Model | undefined
  const mySeat = () => myKart()?.FindFirstChildOfClass("VehicleSeat") as VehicleSeat | undefined

  // The handbrake: Shift, while held.
  const handbrake = (on: boolean) => {
    const seat = player.Character?.FindFirstChildOfClass("Humanoid")?.SeatPart
    if (seat instanceof VehicleSeat) seat.Handbrake = on
  }
  UserInputService.InputBegan.Connect((input, processed) => {
    if (!processed && input.KeyCode === Enum.KeyCode.LeftShift) handbrake(true)
  })
  UserInputService.InputEnded.Connect((input) => {
    if (input.KeyCode === Enum.KeyCode.LeftShift) handbrake(false)
  })

  // "Back on track": the button, or R.
  const ask = () => reset.FireServer()
  UserInputService.InputBegan.Connect((input, processed) => {
    if (!processed && input.KeyCode === Enum.KeyCode.R) ask()
  })
  let wired: TextButton | undefined

  let behind: Vector3 | undefined
  let lapSeen = -1
  let lapClock = 0
  let sinceGo = 99
  const ordinal = (n: number) => `${n}${n === 1 ? "st" : n === 2 ? "nd" : n === 3 ? "rd" : "th"}`
  RunService.RenderStepped.Connect((dt: number) => {
    // The camera: behind the kart and above it, turning after it.
    const chassis: BasePart | undefined = myKart()?.PrimaryPart
    if (chassis) {
      camera.CameraType = Enum.CameraType.Scriptable
      const look = chassis.CFrame.LookVector
      const ahead = new Vector3(look.X, 0, look.Z)
      if (ahead.Magnitude > 0.01) {
        const eased = behind ? behind.Lerp(ahead.Unit, Math.min(1, dt * 6)) : ahead.Unit
        behind = eased.Magnitude > 0.01 ? eased.Unit : ahead.Unit
      }
      if (behind) camera.CFrame = CFrame.lookAt(chassis.Position.sub(behind.mul(16)).add(new Vector3(0, 7, 0)), chassis.Position.add(behind.mul(10)).add(new Vector3(0, 2, 0)))
    }
    // The HUD (copied afresh from StarterGui each time the character spawns).
    const hud = player.PlayerGui?.FindFirstChild("Hud")
    if (!hud) return
    const button = hud.FindFirstChild("Reset") as TextButton | undefined
    if (button && button !== wired) {
      wired = button
      button.Activated.Connect(ask)
    }
    const text = (name: string, value: string) => {
      const label = hud.FindFirstChild(name) as TextLabel | undefined
      if (label && label.Text !== value) label.Text = value
    }
    const phase = Workspace.GetAttribute("Phase") as string | undefined
    const lap = (player.GetAttribute("Lap") as number | undefined) ?? 0
    const finished = player.GetAttribute("Finished") as number | undefined
    // This lap's time, counted here from when the lap changed (the server's own count is what's kept).
    if (lap !== lapSeen) {
      lapSeen = lap
      lapClock = 0
    }
    if (phase === "Racing" && finished === undefined) lapClock += dt
    else if (phase !== "Racing") lapClock = 0
    sinceGo = phase === "Racing" ? sinceGo + dt : phase === "Countdown" ? 0 : 99
    const best = player.GetAttribute("Best") as number | undefined
    const karts = CollectionService.GetTagged("Kart").length
    text("Lap", `Lap ${Math.min(lap + 1, LAPS)}/${LAPS}`)
    text("Time", `Time ${lapClock.toFixed(1)}`)
    text("Best", best === undefined ? "Best -" : `Best ${best.toFixed(2)}`)
    text("Place", `${ordinal((player.GetAttribute("Place") as number | undefined) ?? 1)} of ${karts}`)
    text("Speed", `${Math.round(Math.abs(mySeat()?.ForwardSpeed ?? 0))}`)
    const count = (Workspace.GetAttribute("Count") as number | undefined) ?? 0
    const words =
      finished !== undefined ? `${ordinal((player.GetAttribute("Place") as number | undefined) ?? 1)}  ${finished.toFixed(2)}`
      : phase === "Countdown" && count > 0 ? String(count)
      : phase === "Racing" && sinceGo < 1.2 ? "GO!"
      : phase === "Waiting" ? "Next race soon"
      : phase === "Results" ? "Race over"
      : ""
    const banner = hud.FindFirstChild("Banner") as TextLabel | undefined
    if (banner) {
      banner.Visible = words !== ""
      if (banner.Text !== words) banner.Text = words
    }
  })
}
```

### `server/game/place.ts`

```ts
// Racing: race cars on an asphalt circuit. Three laps, a countdown, live places, and each player's best lap kept.
// - Each player gets a 3D race car on the grid and starts in its seat (a VehicleSeat). W and S are its throttle and A
//   and D its steering, whichever way the camera looks.
// - Each kart is a car of the engine's own (a VehicleSeat and four VehicleWheels): suspension, grip, gears, brakes,
//   driven by its driver's page at once, with no script. Shift is the handbrake (the client script binds it).
// - Karts are anchored on the grid until GO, so nobody jumps the start.
// - The server decides what counts. A lap is the four gates round the road in order, and no quicker than MIN_LAP.
// - Rounds: waiting, the grid and a countdown, the race (LAPS laps, or RACE_SECONDS at most), the results, and again.
import {
  CFrame,
  Color3,
  Enum,
  Instance,
  UDim,
  UDim2,
  Vector2,
  Vector3,
  type BasePart,
  type EnginePlace,
  type GameShellConfig,
  type Humanoid,
  type IntValue,
  type Model,
  type Player,
  type VehicleSeat,
} from "../framework/index"

const CAR_URLS = [
  "https://game-assets.sitemills.com/library/kenney/racing-kit/88d76c6bc5c9/Models/GLTF-format/raceCarRed.glb",
  "https://game-assets.sitemills.com/library/kenney/racing-kit/88d76c6bc5c9/Models/GLTF-format/raceCarGreen.glb",
  "https://game-assets.sitemills.com/library/kenney/racing-kit/88d76c6bc5c9/Models/GLTF-format/raceCarOrange.glb",
  "https://game-assets.sitemills.com/library/kenney/racing-kit/88d76c6bc5c9/Models/GLTF-format/raceCarWhite.glb",
  "https://game-assets.sitemills.com/library/kenney/racing-kit/88d76c6bc5c9/Models/GLTF-format/raceCarRed.glb",
  "https://game-assets.sitemills.com/library/kenney/racing-kit/88d76c6bc5c9/Models/GLTF-format/raceCarGreen.glb",
]
const START_GANTRY_URL = "https://game-assets.sitemills.com/library/kenney/racing-kit/88d76c6bc5c9/Models/GLTF-format/roadStart.glb"
const GRANDSTAND_URL = "https://game-assets.sitemills.com/library/kenney/racing-kit/88d76c6bc5c9/Models/GLTF-format/grandStand.glb"
const RED_BARRIER_URL = "https://game-assets.sitemills.com/library/kenney/racing-kit/88d76c6bc5c9/Models/GLTF-format/barrierRed.glb"
const WHITE_BARRIER_URL = "https://game-assets.sitemills.com/library/kenney/racing-kit/88d76c6bc5c9/Models/GLTF-format/barrierWhite.glb"
const CHECKERED_FLAG_URL = "https://game-assets.sitemills.com/library/kenney/racing-kit/88d76c6bc5c9/Models/GLTF-format/flagCheckers.glb"
const LIGHT_POST_URL = "https://game-assets.sitemills.com/library/kenney/racing-kit/88d76c6bc5c9/Models/GLTF-format/lightPostModern.glb"
const TRACK_TREE_URL = "https://game-assets.sitemills.com/library/kenney/racing-kit/88d76c6bc5c9/Models/GLTF-format/treeLarge.glb"
const READY_SOUND_URL = "https://game-assets.sitemills.com/library/kenney/synth-voice-2/1aa97678ca2a/Audio/ready.ogg"
const GO_SOUND_URL = "https://game-assets.sitemills.com/library/kenney/synth-voice-2/1aa97678ca2a/Audio/go.ogg"
const WINNER_SOUND_URL = "https://game-assets.sitemills.com/library/kenney/synth-voice-2/1aa97678ca2a/Audio/winner.ogg"

export const shell: GameShellConfig = {
  title: "Sunset Circuit",
  subtitle: "Six-car grand prix on a floodlit asphalt circuit — nail the apexes, beat the lap record, and claim the checkered flag.",
  modes: [
    {
      id: "grand-prix",
      name: "3-Lap Grand Prix",
      description: "Up to 6 drivers battle over 3 timed laps.",
      minPlayers: 1,
      maxPlayers: 6,
    },
    {
      id: "time-trial",
      name: "Time Trial",
      description: "Solo hot-lapping for the circuit lap record.",
      minPlayers: 1,
      maxPlayers: 1,
    },
  ],
  howToPlay: [
    "Hold W / S (or thumbstick up/down) for throttle and reverse, and A / D to steer.",
    "Cross all four track sectors in order for each lap to count — tap Back on track if you spin off line.",
  ],
  controls: [
    { keys: "W / S", action: "Throttle / Brake & Reverse" },
    { keys: "A / D", action: "Steer" },
    { keys: "Shift", action: "Handbrake drift" },
    { keys: "R", action: "Back on track" },
    { keys: "M", action: "Expand circuit map" },
    { keys: "Tab", action: "Race standings" },
    { keys: "Esc", action: "Pause & Settings" },
  ],
  minimap: { range: 200, players: "all" },
}

export const LAPS = 3
/** How high a kart's middle is put over the road (its wheels touch it there; it settles a little onto its springs). */
export const RIDE = 0.85
/** Each wheel's radius, and where it is on the car (the model's wheels: invisible ones carry it). */
const WHEEL_RADIUS = 0.8
const WHEELS = [
  { x: -2.1, z: -3.1, front: true },
  { x: 2.1, z: -3.1, front: true },
  { x: -2.1, z: 3.1, front: false },
  { x: 2.1, z: 3.1, front: false },
]
/** The top of the road. */
const ROAD_TOP = 0.2
const WAIT_SECONDS = 4
const COUNT_SECONDS = 3
const RACE_SECONDS = 180
const RESULT_SECONDS = 6
/** No lap is quicker than this (a kart that got round faster didn't go round). */
const MIN_LAP = 6
/** The road is a ring between an outer wall and an island: its outer edge's half sizes, and its width. */
const OUTER = { x: 150, z: 100 }
const ROAD = 36
/** The middle of each side of the road. Karts go along +X on the near side (z = MID.z), then round to the left. */
const MID = { x: OUTER.x - ROAD / 2, z: OUTER.z - ROAD / 2 }
const COLOURS = [Color3.fromRGB(220, 60, 60), Color3.fromRGB(70, 180, 90), Color3.fromRGB(240, 140, 50), Color3.fromRGB(235, 238, 244), Color3.fromRGB(220, 60, 60), Color3.fromRGB(70, 180, 90)]
/** Where each kart starts: behind the line, two abreast. */
const GRID = [0, 1, 2, 3, 4, 5].map((i) => new Vector3(-14 - Math.floor(i / 2) * 12, 0, MID.z + (i % 2 === 0 ? -8 : 8)))
/** The gates, in the order a lap passes them (the first is the line), each with the way karts cross it. */
const GATES = [
  { at: new Vector3(0, 0, MID.z), along: new Vector3(1, 0, 0) },
  { at: new Vector3(MID.x, 0, 0), along: new Vector3(0, 0, -1) },
  { at: new Vector3(0, 0, -MID.z), along: new Vector3(-1, 0, 0) },
  { at: new Vector3(-MID.x, 0, 0), along: new Vector3(0, 0, 1) },
]

type Racer = { player: Player; slot: number; kart: Model; lap: number; next: number; lapStart: number; finished: number | undefined; resetAt: number }

export const place: EnginePlace = ({ Workspace, Players, Lighting, ReplicatedStorage, StarterGui, CollectionService, DataStoreService, task }) => {
  Lighting.ClockTime = 16.8
  new Instance("Sky", Lighting)

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
  const trackside = (name: string, meshId: string, size: Vector3, cf: CFrame) => {
    const m = new Instance("MeshPart")
    m.Name = name
    m.MeshId = meshId
    m.Anchored = true
    m.CanCollide = false
    m.CanQuery = false
    m.CanTouch = false
    m.Size = size
    m.CFrame = cf
    m.Parent = Workspace
    return m
  }

  // The track: grass field, seamless asphalt road slab, grassy infield island, and outer safety walls.
  part("Ground", new Vector3(520, 2, 420), new Vector3(0, -1, 0), Color3.fromRGB(96, 150, 76), Enum.Material.Grass)
  part("Road", new Vector3(OUTER.x * 2, ROAD_TOP, OUTER.z * 2), new Vector3(0, ROAD_TOP / 2, 0), Color3.fromRGB(58, 60, 66), Enum.Material.Asphalt)
  part("Island", new Vector3((OUTER.x - ROAD) * 2, 2.2, (OUTER.z - ROAD) * 2), new Vector3(0, 1.1, 0), Color3.fromRGB(86, 140, 70), Enum.Material.LeafyGrass)
  for (const [x, z, w, d] of [[0, OUTER.z + 1, OUTER.x * 2 + 4, 2], [0, -OUTER.z - 1, OUTER.x * 2 + 4, 2], [OUTER.x + 1, 0, 2, OUTER.z * 2], [-OUTER.x - 1, 0, 2, OUTER.z * 2]]) {
    part("Wall", new Vector3(w, 4, d), new Vector3(x, 2, z), Color3.fromRGB(224, 224, 230), Enum.Material.Concrete)
  }
  part("Line", new Vector3(3, 0.05, ROAD), new Vector3(0, 0.23, MID.z), Color3.fromRGB(245, 245, 245)).CanCollide = false

  // 3D start gantry, checkered flags, spectator grandstands, apex barriers, floodlights, and infield trees.
  trackside("StartGantry", START_GANTRY_URL, new Vector3(44, 23.4, 70), new CFrame(0, 11.15, MID.z).mul(CFrame.Angles(0, Math.PI / 2, 0)))
  for (const side of [-1, 1]) {
    trackside("FinishFlag", CHECKERED_FLAG_URL, new Vector3(2.4, 15, 0.6), new CFrame(2, 8.5, MID.z + side * (ROAD / 2 + 2)))
  }
  for (const gx of [-54, -18, 18, 54]) {
    trackside("Grandstand", GRANDSTAND_URL, new Vector3(24, 21.5, 24), new CFrame(gx, 10.75, OUTER.z + 18).mul(CFrame.Angles(0, Math.PI, 0)))
  }
  for (const [sx, sz] of [[1, 1], [1, -1], [-1, -1], [-1, 1]] as const) {
    for (let i = 0; i < 5; i++) {
      const url = i % 2 === 0 ? RED_BARRIER_URL : WHITE_BARRIER_URL
      trackside(
        "ApexBarrier",
        url,
        new Vector3(6, 3.1, 3),
        new CFrame(sx * (OUTER.x - ROAD - 4 - i * 6.2), 3.7, sz * (OUTER.z - ROAD - 2)),
      )
    }
  }
  for (const lx of [-110, -45, 45, 110]) {
    trackside("Floodlight", LIGHT_POST_URL, new Vector3(1, 14.1, 3.2), new CFrame(lx, 7.1, OUTER.z + 4).mul(CFrame.Angles(0, Math.PI, 0)))
    trackside("Floodlight", LIGHT_POST_URL, new Vector3(1, 14.1, 3.2), new CFrame(lx, 7.1, -OUTER.z - 4))
  }
  for (const [tx, tz] of [[-70, -28], [-25, 22], [28, -24], [72, 26], [0, 0], [-88, 16], [88, -16]] as const) {
    trackside("InfieldTree", TRACK_TREE_URL, new Vector3(5, 18.5, 5.5), new CFrame(tx, 11, tz))
  }

  // The round: its phase and the countdown are attributes on Workspace, for every page's HUD.
  let phase = "Waiting"
  const setPhase = (next: string) => {
    phase = next
    Workspace.SetAttribute("Phase", next)
  }
  setPhase("Waiting")
  Workspace.SetAttribute("Count", 0)
  const now = () => Workspace.DistributedGameTime
  const racers = new Map<Player, Racer>()
  const byKart = new Map<Model, Racer>()
  const seconds = (t: number) => t.toFixed(2)

  // Each player's best lap, in hundredths of a second (an ordered store, so it can be a leaderboard), and wins here.
  const bestLaps = DataStoreService.GetOrderedDataStore("BestLap")
  let record: { time: number; name: string } | undefined
  let lastRace: string[] = []

  // The board on a gantry over the road, just past the line, facing the grid: the lap record, and the last race's finish.
  const board = part("Board", new Vector3(0.6, 6, ROAD - 2), new Vector3(34, 12, MID.z), Color3.fromRGB(24, 26, 34), Enum.Material.Metal)
  for (const side of [-1, 1]) part("Post", new Vector3(1.2, 15, 1.2), new Vector3(34, 7.5, MID.z + side * (ROAD / 2 - 0.6)), Color3.fromRGB(90, 94, 104), Enum.Material.Metal)
  const screen = new Instance("SurfaceGui", board)
  screen.Face = Enum.NormalId.Left
  screen.CanvasSize = new Vector2(850, 150)
  screen.LightInfluence = 0
  const line = (name: string, y: number, height: number, color: Color3) => {
    const l = new Instance("TextLabel", screen)
    l.Name = name
    l.Position = UDim2.fromOffset(0, y)
    l.Size = new UDim2(1, 0, 0, height)
    l.BackgroundTransparency = 1
    l.Font = Enum.Font.GothamBold
    l.TextScaled = true
    l.TextColor3 = color
    l.Text = ""
    return l
  }
  const boardRecord = line("Record", 10, 76, Color3.fromRGB(255, 220, 90))
  const boardLast = line("Last", 94, 54, Color3.fromRGB(200, 225, 255))
  const showBoard = () => {
    boardRecord.Text = record ? `LAP RECORD  ${seconds(record.time)}  ${record.name}` : "LAP RECORD  -"
    boardLast.Text = lastRace.length > 0 ? lastRace.join("    ") : `${LAPS} laps`
  }
  showBoard()

  // Countdown, start, and finish announcer sounds.
  const beep = new Instance("Sound", Workspace)
  beep.Name = "Beep"
  beep.SoundId = READY_SOUND_URL
  const go = new Instance("Sound", Workspace)
  go.Name = "Go"
  go.SoundId = GO_SOUND_URL
  const victorySound = new Instance("Sound", Workspace)
  victorySound.Name = "Winner"
  victorySound.SoundId = WINNER_SOUND_URL

  // Karts ---------------------------------------------------------------------------------------------------------------

  const gridCFrame = (slot: number) => CFrame.lookAt(new Vector3(GRID[slot].X, ROAD_TOP + RIDE, GRID[slot].Z), new Vector3(GRID[slot].X + 1, ROAD_TOP + RIDE, GRID[slot].Z))
  /** A race car: an invisible chassis, a seat, four invisible wheels that carry it, and a 3D race car model welded on. */
  const makeKart = (player: Player, slot: number) => {
    const kart = new Instance("Model")
    kart.Name = "Kart"
    const frame = gridCFrame(slot)
    const chassis = new Instance("Part")
    chassis.Name = "Chassis"
    chassis.Size = new Vector3(4, 1, 7)
    chassis.Color = COLOURS[slot]
    chassis.Transparency = 1
    chassis.CFrame = frame
    // Held on the grid unless a race is on (someone joining mid-race drives at once).
    chassis.Anchored = phase !== "Racing"
    chassis.Parent = kart

    const carMesh = new Instance("MeshPart")
    carMesh.Name = "CarBody"
    carMesh.MeshId = CAR_URLS[slot % CAR_URLS.length]
    carMesh.Size = new Vector3(5.2, 2.8, 9.4)
    carMesh.CanCollide = false
    carMesh.CanQuery = false
    carMesh.CanTouch = false
    carMesh.Massless = true
    carMesh.CFrame = frame.mul(new CFrame(0, 0.55, 0)).mul(CFrame.Angles(0, Math.PI, 0))
    carMesh.Parent = kart
    const meshWeld = new Instance("WeldConstraint", carMesh)
    meshWeld.Part0 = chassis
    meshWeld.Part1 = carMesh

    const seat = new Instance("VehicleSeat")
    seat.CFrame = frame.mul(new CFrame(0, 0.75, 0.6))
    seat.Transparency = 1
    // Tuned for the circuit: brisk, forgiving (Assist 1 is arcade; lower it for a sim).
    seat.MaxSpeed = 75
    seat.Torque = 11
    seat.TurnSpeed = 1.5
    seat.Parent = kart
    const hold = new Instance("WeldConstraint", seat)
    hold.Part0 = chassis
    hold.Part1 = seat

    for (const w of WHEELS) {
      const wheel = new Instance("Part")
      wheel.Name = w.front ? "FrontWheel" : "RearWheel"
      wheel.Shape = Enum.PartType.Cylinder
      wheel.Size = new Vector3(0.8, WHEEL_RADIUS * 2, WHEEL_RADIUS * 2)
      wheel.Transparency = 1
      wheel.CFrame = frame.mul(new CFrame(w.x, WHEEL_RADIUS - RIDE, w.z))
      wheel.Parent = kart
      const spec = new Instance("VehicleWheel")
      spec.Steer = w.front
      spec.SuspensionLength = 0.6
      spec.Parent = wheel
      const axle = new Instance("WeldConstraint", wheel)
      axle.Part0 = chassis
      axle.Part1 = wheel
    }

    kart.PrimaryPart = chassis
    kart.SetAttribute("Owner", player.UserId)
    CollectionService.AddTag(kart, "Kart")
    kart.Parent = Workspace
    return kart
  }
  const seatOf = (kart: Model) => kart.FindFirstChildOfClass("VehicleSeat") as VehicleSeat
  const seatIn = (racer: Racer) => {
    const humanoid = racer.player.Character?.FindFirstChildOfClass("Humanoid") as Humanoid | undefined
    const seat = seatOf(racer.kart)
    if (humanoid && humanoid.Health > 0 && seat.Occupant !== humanoid) seat.Sit(humanoid)
  }
  const putKart = (racer: Racer, at: CFrame) => {
    racer.kart.PivotTo(at)
    const chassis = racer.kart.PrimaryPart as BasePart
    chassis.AssemblyLinearVelocity = Vector3.zero
    chassis.AssemblyAngularVelocity = Vector3.zero
    seatIn(racer)
  }
  /** On the grid the karts are held (anchored); at GO they're let go (and their drivers' again). */
  const hold = (held: boolean) => {
    for (const racer of racers.values()) (racer.kart.PrimaryPart as BasePart).Anchored = held
  }

  Players.PlayerAdded.Connect(async (player) => {
    const stats = new Instance("Folder")
    stats.Name = "leaderstats"
    new Instance("IntValue", stats).Name = "Wins"
    stats.Parent = player
    const taken = new Set([...racers.values()].map((r) => r.slot))
    const slot = [0, 1, 2, 3, 4, 5].find((s) => !taken.has(s))
    if (slot === undefined) return
    const racer: Racer = { player, slot, kart: makeKart(player, slot), lap: 0, next: 1, lapStart: now(), finished: undefined, resetAt: -9 }
    racers.set(player, racer)
    byKart.set(racer.kart, racer)
    player.SetAttribute("Lap", 0)
    player.SetAttribute("Place", racers.size)
    player.CharacterAdded.Connect(() => task.delay(0.3, () => racers.get(player) === racer && seatIn(racer)))
    if (player.Character) task.delay(0.3, () => racers.get(player) === racer && seatIn(racer))
    const best = (await bestLaps.GetAsync(String(player.UserId))) as number | undefined
    if (best !== undefined && racers.get(player) === racer) player.SetAttribute("Best", best / 100)
  })
  Players.PlayerRemoving.Connect((player) => {
    const racer = racers.get(player)
    if (!racer) return
    racers.delete(player)
    byKart.delete(racer.kart)
    racer.kart.Destroy()
  })

  // Laps ----------------------------------------------------------------------------------------------------------------

  const finish = (racer: Racer, total: number) => {
    racer.finished = total
    racer.player.SetAttribute("Finished", total)
    victorySound.Play()
  }
  const lapDone = async (racer: Racer) => {
    const time = now() - racer.lapStart
    if (time < MIN_LAP) return
    racer.lap += 1
    racer.lapStart = now()
    racer.player.SetAttribute("Lap", racer.lap)
    const name = racer.player.DisplayName || racer.player.Name
    if (!record || time < record.time) {
      record = { time, name }
      showBoard()
    }
    if (racer.lap === LAPS) finish(racer, now() - raceStart)
    const best = racer.player.GetAttribute("Best") as number | undefined
    if (best === undefined || time < best) {
      racer.player.SetAttribute("Best", Math.round(time * 100) / 100)
      await bestLaps.SetAsync(String(racer.player.UserId), Math.round(time * 100))
    }
  }
  GATES.forEach((gate, index) => {
    const across = Math.abs(gate.along.X) > 0 ? new Vector3(12, 8, ROAD) : new Vector3(ROAD, 8, 12)
    const trigger = part(`Gate${index}`, across, new Vector3(gate.at.X, 4, gate.at.Z), Color3.fromRGB(255, 255, 255))
    trigger.Transparency = 1
    trigger.CanCollide = false
    trigger.CanQuery = false
    trigger.Touched.Connect((hit) => {
      const kart = hit.FindFirstAncestorOfClass("Model")
      const racer = kart ? byKart.get(kart) : undefined
      if (!racer || phase !== "Racing" || racer.finished !== undefined || racer.next !== index) return
      racer.next = (index + 1) % GATES.length
      if (index === 0) void lapDone(racer)
    })
  })

  // "Back on track": the kart goes to the last gate it passed, facing the way of the road.
  const reset = new Instance("RemoteEvent")
  reset.Name = "Reset"
  reset.Parent = ReplicatedStorage
  reset.OnServerEvent.Connect((player) => {
    const racer = racers.get(player)
    if (!racer || phase !== "Racing" || now() - racer.resetAt < 2) return
    racer.resetAt = now()
    const gate = GATES[(racer.next + GATES.length - 1) % GATES.length]
    const at = new Vector3(gate.at.X, ROAD_TOP + RIDE, gate.at.Z)
    putKart(racer, CFrame.lookAt(at, at.add(gate.along)))
  })

  // The round ---------------------------------------------------------------------------------------------------------

  let raceStart = 0
  const places = () => {
    const progress = (r: Racer) => {
      const next = GATES[r.next].at
      const at = (r.kart.PrimaryPart as BasePart).Position
      return r.lap * GATES.length + ((r.next + GATES.length - 1) % GATES.length) - Math.hypot(next.X - at.X, next.Z - at.Z) / 1000
    }
    return [...racers.values()].sort((a, b) => {
      if (a.finished !== undefined || b.finished !== undefined) return (a.finished ?? Infinity) - (b.finished ?? Infinity)
      return progress(b) - progress(a)
    })
  }
  const round = async () => {
    for (;;) {
      setPhase("Waiting")
      // Back to the grid, held there until GO.
      for (const racer of racers.values()) putKart(racer, gridCFrame(racer.slot))
      hold(true)
      while (racers.size === 0) await task.wait(0.5)
      await task.wait(WAIT_SECONDS)
      for (const racer of racers.values()) {
        racer.finished = undefined
        racer.player.SetAttribute("Finished", undefined)
        racer.player.SetAttribute("Lap", 0)
        putKart(racer, gridCFrame(racer.slot))
      }
      hold(true)
      setPhase("Countdown")
      beep.Play()
      for (let count = COUNT_SECONDS; count > 0; count--) {
        Workspace.SetAttribute("Count", count)
        await task.wait(1)
      }
      Workspace.SetAttribute("Count", 0)
      go.Play()
      raceStart = now()
      for (const racer of racers.values()) {
        racer.lap = 0
        racer.next = 1
        racer.lapStart = raceStart
      }
      hold(false)
      setPhase("Racing")
      while (now() - raceStart < RACE_SECONDS && racers.size > 0 && [...racers.values()].some((r) => r.finished === undefined)) {
        places().forEach((racer, i) => racer.player.SetAttribute("Place", i + 1))
        await task.wait(0.25)
      }
      const order = places()
      order.forEach((racer, i) => racer.player.SetAttribute("Place", i + 1))
      lastRace = order.slice(0, 3).map((racer, i) => `${i + 1}. ${racer.player.DisplayName || racer.player.Name}${racer.finished !== undefined ? ` ${seconds(racer.finished)}` : ""}`)
      showBoard()
      const winner = order[0]
      const wins = winner?.finished !== undefined ? (winner.player.FindFirstChild("leaderstats")?.FindFirstChild("Wins") as IntValue | undefined) : undefined
      if (wins) wins.Value += 1
      setPhase("Results")
      await task.wait(RESULT_SECONDS)
    }
  }
  void round()

  // The HUD (the client script fills it in): the lap, its time, the best lap, the place, the speed, and a banner.
  const hud = new Instance("ScreenGui")
  hud.Name = "Hud"
  const label = (name: string, x: number, y: number, width: number) => {
    const l = new Instance("TextLabel", hud)
    l.Name = name
    l.Size = UDim2.fromOffset(width, 34)
    l.Position = UDim2.fromOffset(x, y)
    l.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
    l.BackgroundTransparency = 0.25
    l.BorderSizePixel = 0
    l.TextColor3 = Color3.fromRGB(255, 255, 255)
    l.Font = Enum.Font.GothamBold
    l.TextSize = 18
    l.Text = ""
    new Instance("UICorner", l).CornerRadius = new UDim(0, 10)
    return l
  }
  label("Lap", 16, 16, 150)
  label("Time", 16, 56, 150)
  label("Best", 16, 96, 150).TextColor3 = Color3.fromRGB(255, 215, 80)
  label("Place", 174, 16, 116).TextSize = 22
  const speed = label("Speed", 0, 0, 110)
  speed.AnchorPoint = new Vector2(1, 1)
  speed.Position = new UDim2(1, -16, 1, -16)
  speed.Size = UDim2.fromOffset(110, 56)
  speed.TextSize = 28
  const back = new Instance("TextButton", hud)
  back.Name = "Reset"
  back.AnchorPoint = new Vector2(1, 1)
  back.Position = new UDim2(1, -134, 1, -16)
  back.Size = UDim2.fromOffset(130, 56)
  back.BackgroundColor3 = Color3.fromRGB(40, 48, 68)
  back.BackgroundTransparency = 0.2
  back.TextColor3 = Color3.fromRGB(255, 255, 255)
  back.Font = Enum.Font.GothamBold
  back.TextSize = 15
  back.Text = "Back on track"
  new Instance("UICorner", back).CornerRadius = new UDim(0, 10)
  const banner = label("Banner", 0, 0, 520)
  banner.AnchorPoint = new Vector2(0.5, 0.5)
  banner.Position = UDim2.fromScale(0.5, 0.32)
  banner.Size = UDim2.fromOffset(520, 86)
  banner.TextSize = 44
  banner.Visible = false
  hud.Parent = StarterGui
}
```

### `server/game/tests.ts`

```ts
// The game's own tests: they run on every build. testGame plays the place on a test server, and each player who joins
// is a client running the game's client script, as their page does. Time passes with `await t.wait(seconds)`.
import { describe, expect, test } from "../../api/test-framework.js"
import { Vector3, testGame, type BasePart, type Humanoid, type Model, type TextLabel } from "../framework/index"
import { client } from "./client"
import { place } from "./place"

/** What these tests need of a running game. (A game's server code has no Awaited type, so it's spelled out.) */
type Game = { services: { CollectionService: { GetTagged(tag: string): { GetAttribute(name: string): unknown }[] }; Workspace: { GetAttribute(name: string): unknown } } }
const kartOf = (t: Game, userId: number) => t.services.CollectionService.GetTagged("Kart").find((k) => k.GetAttribute("Owner") === userId) as unknown as Model
const phase = (t: Game) => t.services.Workspace.GetAttribute("Phase")

describe("the racing game", () => {
  test("a player starts in their kart on the grid; it's held through the countdown, and drives at GO (theirs to drive)", async () => {
    const t = await testGame(place, { client })
    const ana = t.join("Ana")
    await t.wait(1.5)
    const kart = kartOf(t, ana.serverPlayer.UserId)
    const chassis = kart.PrimaryPart as BasePart
    const humanoid = ana.serverPlayer.Character?.FindFirstChildOfClass("Humanoid") as Humanoid
    expect(humanoid.SeatPart === kart.FindFirstChildOfClass("VehicleSeat")).toBe(true)
    // Throttle held from the start (the kart faces +X on the grid): nothing happens until the race is on.
    ana.input(new Vector3(1, 0, 0))
    const from = chassis.Position
    await t.wait(3)
    expect(phase(t) === "Racing").toBe(false)
    expect(chassis.Position.sub(from).Magnitude).toBeLessThan(1)
    while (phase(t) !== "Racing") await t.wait(0.25)
    await t.wait(2.5)
    // Away down the straight, driven by its driver's client, and the server has it where that client put it.
    expect(chassis.Position.X - from.X > 35).toBe(true)
    expect(chassis.GetNetworkOwner() === ana.serverPlayer).toBe(true)
    const mine = (ana.services.CollectionService.GetTagged("Kart")[0] as Model).PrimaryPart as BasePart
    expect(mine.Position.sub(chassis.Position).Magnitude).toBeLessThan(6)
    const speed = ana.player?.FindFirstChild("PlayerGui")?.FindFirstChild("Hud")?.FindFirstChild("Speed") as TextLabel
    expect(Number(speed.Text) > 30).toBe(true)
  })

  test("a lap is the four gates in order: driven round the road, it counts, with its time kept as the best", async () => {
    const t = await testGame(place, { client })
    const ana = t.join("Ana")
    while (phase(t) !== "Racing") await t.wait(0.25)
    const chassis = kartOf(t, ana.serverPlayer.UserId).PrimaryPart as BasePart
    // A driver: toward each point round the middle of the road in turn, steering by how far off it's pointing and
    // easing off the throttle when that's a lot (a car turns wide at full speed). Its keys are the kart's own controls.
    // The middle of the road all round: each corner and each straight's middle (never across the island).
    const corners = [new Vector3(66, 0, 82), new Vector3(132, 0, 82), new Vector3(132, 0, 0), new Vector3(132, 0, -82), new Vector3(0, 0, -82), new Vector3(-132, 0, -82), new Vector3(-132, 0, 0), new Vector3(-132, 0, 82), new Vector3(-66, 0, 82)]
    let corner = 0
    let waited = 0
    while (((ana.serverPlayer.GetAttribute("Lap") as number | undefined) ?? 0) < 1 && waited < 40) {
      let to = corners[corner].sub(chassis.Position)
      if (Math.hypot(to.X, to.Z) < 30) {
        corner = (corner + 1) % corners.length
        to = corners[corner].sub(chassis.Position)
      }
      const look = chassis.CFrame.LookVector
      const right = chassis.CFrame.RightVector
      const off = Math.atan2(to.X * right.X + to.Z * right.Z, to.X * look.X + to.Z * look.Z)
      ana.input(look.mul(Math.abs(off) > 0.45 ? 0.45 : 1).add(right.mul(Math.max(-1, Math.min(1, off * 2.5)))))
      await t.wait(0.1)
      waited += 0.1
    }
    expect(ana.serverPlayer.GetAttribute("Lap")).toBe(1)
    const best = ana.serverPlayer.GetAttribute("Best") as number
    expect(best > 6 && best < 30).toBe(true)
    // Her page shows it (a moment later: it hears of the lap from the server), and the board has the record.
    await t.wait(0.5)
    const hud = ana.player?.FindFirstChild("PlayerGui")?.FindFirstChild("Hud")
    expect((hud?.FindFirstChild("Lap") as TextLabel).Text).toBe("Lap 2/3")
    expect((hud?.FindFirstChild("Best") as TextLabel).Text).toBe(`Best ${best.toFixed(2)}`)
    const record = (t.services.Workspace.FindFirstChild("Board")?.FindFirstChildOfClass("SurfaceGui")?.FindFirstChild("Record") as TextLabel).Text
    expect(record).toBe(`LAP RECORD  ${best.toFixed(2)}  Ana`)
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
