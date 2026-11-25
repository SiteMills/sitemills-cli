# Starter game: Strategy (RTS)

A real-time strategy game seen from above, with no avatar: each player gets a town hall and workers in a corner. Select units with a click or a dragged box, right-click (or tap) to send them; workers gather gold from a mine, and the town hall trains workers and soldiers. Soldiers sent at an enemy fight it. Raiders hold a camp in the middle and raid the town halls: a town hall that falls is a defeat, and the camp falling is a victory. Units are NPCs in a collision group that passes through itself.

Template `rts`, on SiteMills game framework 1.0 (release 1.0.0). [The Games Guide](../../GAMES_GUIDE.md) says how to make it your game.

## Start from it

With the CLI, in one step:

```bash
sitemills-cli game create "My Game" --template rts
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
// The game's client script: the camera over the map, choosing units, and sending them orders.
// - The camera is Scriptable: it looks down at a point on the ground from above. WASD or the arrow keys move it, the
//   wheel zooms, and on a touch screen a one-finger drag moves it.
// - A click on one of your units selects it; dragging a box selects your units inside it. Each selected unit has a
//   Highlight (made here, so only this player sees it).
// - A right click (or a tap, on a touch screen) sends the selected units there: to a gold mine, workers gather.
import {
  CFrame,
  Color3,
  Enum,
  Instance,
  UDim2,
  Vector3,
  type BasePart,
  type ClientScript,
  type Frame,
  type InputObject,
  type IntValue,
  type Model,
  type RemoteEvent,
  type TextButton,
  type TextLabel,
} from "../framework/index"

/** How the camera looks down: its angle below level, and its distance from the point it looks at (zoom). */
const PITCH = (55 * Math.PI) / 180
const ZOOM = { start: 60, min: 25, max: 220 }
/** Pixels the pointer moves before a press counts as a drag (a box, or panning by touch). */
const DRAG = 8

export const client: ClientScript = ({ player, Workspace, ReplicatedStorage, StarterGui, UserInputService, RunService, CollectionService }) => {
  const command = ReplicatedStorage.FindFirstChild("Command") as RemoteEvent
  const camera = Workspace.CurrentCamera
  camera.CameraType = Enum.CameraType.Scriptable

  // With no character, StarterGui isn't copied into PlayerGui (as in Roblox), so the HUD is copied here.
  const hud = (StarterGui.FindFirstChild("Hud") as Instance).Clone() as Instance
  hud.Parent = player.PlayerGui
  const box = hud.FindFirstChild("SelectBox") as Frame
  ;(hud.FindFirstChild("Train") as TextButton).Activated.Connect(() => command.FireServer("train"))
  ;(hud.FindFirstChild("TrainSoldier") as TextButton).Activated.Connect(() => command.FireServer("trainSoldier"))

  // The camera: the point it looks at, and how far away it is.
  let focus = new Vector3(0, 0, 0)
  let zoom = ZOOM.start
  let centred = false
  const placeCamera = () => {
    const eye = focus.add(new Vector3(0, Math.sin(PITCH) * zoom, Math.cos(PITCH) * zoom))
    camera.CFrame = CFrame.lookAt(eye, focus)
  }

  // Units: mine are tagged Unit with my UserId as their Owner.
  const isMine = (unit: Instance | undefined): unit is Model => !!unit && unit.HasTag("Unit") && unit.GetAttribute("Owner") === player.UserId
  const unitAt = (part: Instance | undefined) => {
    for (let at = part; at; at = at.Parent) if (at.HasTag("Unit")) return at as Model
    return undefined
  }
  const selected = new Map<Model, Instance>()
  const select = (units: Model[], add = false) => {
    if (!add) {
      for (const highlight of selected.values()) highlight.Destroy()
      selected.clear()
    }
    for (const unit of units) {
      if (selected.has(unit)) continue
      const highlight = new Instance("Highlight")
      highlight.Adornee = unit
      highlight.FillColor = Color3.fromRGB(120, 200, 255)
      highlight.FillTransparency = 0.7
      highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
      highlight.Parent = hud
      selected.set(unit, highlight)
    }
  }

  // What's under a point on the screen: the first part along the camera's ray through it.
  const pick = (x: number, y: number) => {
    const ray = camera.ViewportPointToRay(x, y)
    return Workspace.Raycast(ray.Origin, ray.Direction.mul(1000))
  }
  const order = (x: number, y: number) => {
    const hit = pick(x, y)
    if (hit && selected.size > 0) command.FireServer("move", [...selected.keys()], hit.Position)
  }

  // Mouse: press, drag a box, release. A short press is a click.
  let press: { x: number; y: number; touch: boolean; dragged: boolean; focus: Vector3 } | null = null
  const showBox = (x: number, y: number) => {
    if (!press) return
    box.Visible = true
    box.Position = UDim2.fromOffset(Math.min(press.x, x), Math.min(press.y, y))
    box.Size = UDim2.fromOffset(Math.abs(x - press.x), Math.abs(y - press.y))
  }
  UserInputService.InputBegan.Connect((input: InputObject, processed: boolean) => {
    if (processed) return
    const type = input.UserInputType
    if (type === Enum.UserInputType.MouseButton1 || type === Enum.UserInputType.Touch) {
      press = { x: input.Position.X, y: input.Position.Y, touch: type === Enum.UserInputType.Touch, dragged: false, focus }
    } else if (type === Enum.UserInputType.MouseButton2) order(input.Position.X, input.Position.Y)
  })
  UserInputService.InputChanged.Connect((input: InputObject) => {
    const type = input.UserInputType
    if (type === Enum.UserInputType.MouseWheel) zoom = Math.min(ZOOM.max, Math.max(ZOOM.min, zoom * (input.Position.Z > 0 ? 0.85 : 1.18)))
    if (!press || (type !== Enum.UserInputType.MouseMovement && type !== Enum.UserInputType.Touch)) return
    const [x, y] = [input.Position.X, input.Position.Y]
    if (Math.hypot(x - press.x, y - press.y) > DRAG) press.dragged = true
    if (!press.dragged) return
    if (press.touch) {
      // A finger drags the map: the ground under it stays under it (about).
      const studsPerPixel = zoom / Math.max(camera.ViewportSize.Y, 1)
      focus = press.focus.add(new Vector3(-(x - press.x) * studsPerPixel, 0, -(y - press.y) * studsPerPixel * 1.3))
    } else showBox(x, y)
  })
  UserInputService.InputEnded.Connect((input: InputObject) => {
    const type = input.UserInputType
    if (!press || (type !== Enum.UserInputType.MouseButton1 && type !== Enum.UserInputType.Touch)) return
    const [x, y] = [input.Position.X, input.Position.Y]
    const was = press
    press = null
    box.Visible = false
    if (was.touch) {
      if (was.dragged) return
      // A tap: on one of mine, it's selected (with the rest); anywhere else, the selection goes there.
      const unit = unitAt(pick(x, y)?.Instance)
      if (isMine(unit)) select([unit], true)
      else order(x, y)
      return
    }
    if (!was.dragged) {
      const unit = unitAt(pick(x, y)?.Instance)
      select(isMine(unit) ? [unit] : [])
      return
    }
    // A box: every unit of mine whose middle is inside it on the screen.
    const [left, right, top, bottom] = [Math.min(was.x, x), Math.max(was.x, x), Math.min(was.y, y), Math.max(was.y, y)]
    const inside = CollectionService.GetTagged("Unit").filter((unit) => {
      if (!isMine(unit)) return false
      const root = unit.FindFirstChild("HumanoidRootPart") as BasePart | undefined
      if (!root) return false
      const [screen, visible] = camera.WorldToViewportPoint(root.Position)
      return visible && screen.X >= left && screen.X <= right && screen.Y >= top && screen.Y <= bottom
    }) as Model[]
    select(inside)
  })

  RunService.RenderStepped.Connect((dt: number) => {
    // Start over my town hall's workers (in front of it, toward the middle of the map), once it's here.
    if (!centred) {
      const hall = CollectionService.GetTagged("TownHall").find((h) => h.GetAttribute("Owner") === player.UserId) as Model | undefined
      if (hall) {
        const at = hall.GetPivot().Position
        focus = new Vector3(at.X, 0, at.Z).add(new Vector3(-at.X, 0, -at.Z).Unit.mul(14))
        centred = true
      }
    }
    // Keys move the view (faster when it's zoomed out).
    const speed = zoom * 1.2 * dt
    const key = (...codes: (typeof Enum.KeyCode.W)[]) => codes.some((c) => UserInputService.IsKeyDown(c))
    if (key(Enum.KeyCode.W, Enum.KeyCode.Up)) focus = focus.add(new Vector3(0, 0, -speed))
    if (key(Enum.KeyCode.S, Enum.KeyCode.Down)) focus = focus.add(new Vector3(0, 0, speed))
    if (key(Enum.KeyCode.A, Enum.KeyCode.Left)) focus = focus.add(new Vector3(-speed, 0, 0))
    if (key(Enum.KeyCode.D, Enum.KeyCode.Right)) focus = focus.add(new Vector3(speed, 0, 0))
    focus = new Vector3(Math.max(-200, Math.min(200, focus.X)), 0, Math.max(-200, Math.min(200, focus.Z)))
    placeCamera()
    // Units that are gone (or no longer mine) leave the selection.
    for (const [unit, highlight] of selected) {
      if (unit.Parent && isMine(unit)) continue
      highlight.Destroy()
      selected.delete(unit)
    }
    const stat = (name: string) => (player.FindFirstChild("leaderstats")?.FindFirstChild(name) as IntValue | undefined)?.Value ?? 0
    ;(hud.FindFirstChild("Gold") as TextLabel).Text = `Gold: ${stat("Gold")}`
    ;(hud.FindFirstChild("Units") as TextLabel).Text = `Units: ${stat("Units")}`
    ;(hud.FindFirstChild("Selected") as TextLabel).Text = `Selected: ${selected.size}`
    // The game's end, when it comes: the camp fell (a victory), or my town hall did (a defeat).
    const result = player.GetAttribute("Result") as string | undefined
    const banner = hud.FindFirstChild("Result") as TextLabel
    banner.Visible = result !== undefined
    if (result !== undefined) {
      banner.Text = result.toUpperCase()
      banner.TextColor3 = result === "Victory" ? Color3.fromRGB(120, 255, 150) : Color3.fromRGB(255, 110, 100)
    }
  })
}
```

### `server/game/place.ts`

```ts
// Strategy: a map seen from above, and no avatar. Each player who joins gets a stone keep and three workers in a corner
// of the map. Workers sent to a gold mine gather from it and carry the gold home; the keep trains more workers.
// - Players.CharacterAutoLoads is false, so players have no character. The client script flies a Scriptable camera
//   over the map, selects units (a click, or a box dragged around them) and sends orders through the Command remote.
// - Units are NPCs the server moves (Humanoid.MoveTo, around rocks with PathfindingService). They're in the "Units"
//   collision group, which doesn't collide with itself, so a crowd of them passes through itself instead of jamming.
// - The server checks every order: a player orders only their own units.
// - Fighting: the keep also trains soldiers. Sent at an enemy (a unit or a building), they walk there and strike
//   it; left alone, they strike any enemy that comes in sight. Raiders hold a stronghold in the middle of the map and
//   send raids at the keeps. A keep that falls is a defeat for its player; the stronghold falling is a victory.
import {
  CFrame,
  Color3,
  Enum,
  Instance,
  UDim,
  UDim2,
  Vector2,
  Vector3,
  defaultCharacter,
  type AnimationTrack,
  type BasePart,
  type EnginePlace,
  type Frame,
  type GameShellConfig,
  type Humanoid,
  type IntValue,
  type Model,
  type Player,
} from "../framework/index"

const KEEP_TOWER_URL = "https://game-assets.sitemills.com/library/kenney/castle-kit/a2095edf1a6e/Models/GLB-format/tower-square-base.glb"
const KEEP_ROOF_URL = "https://game-assets.sitemills.com/library/kenney/castle-kit/a2095edf1a6e/Models/GLB-format/tower-square-roof.glb"
const KEEP_FLAG_URL = "https://game-assets.sitemills.com/library/kenney/castle-kit/a2095edf1a6e/Models/GLB-format/flag-wide.glb"
const RAIDER_BASTION_URL = "https://game-assets.sitemills.com/library/kenney/castle-kit/a2095edf1a6e/Models/GLB-format/tower-hexagon-base.glb"
const RAIDER_ROOF_URL = "https://game-assets.sitemills.com/library/kenney/castle-kit/a2095edf1a6e/Models/GLB-format/tower-hexagon-roof.glb"
const TENT_URL = "https://game-assets.sitemills.com/library/kenney/survival-kit/816597879919/Models/GLB-format/tent.glb"
const PINE_URL = "https://game-assets.sitemills.com/library/kenney/survival-kit/816597879919/Models/GLB-format/tree.glb"
const TALL_PINE_URL = "https://game-assets.sitemills.com/library/kenney/survival-kit/816597879919/Models/GLB-format/tree-tall.glb"
const BOULDER_URL = "https://game-assets.sitemills.com/library/kenney/survival-kit/816597879919/Models/GLB-format/rock-b.glb"
const CRYSTAL_URL = "https://game-assets.sitemills.com/library/kenney/tower-defense-kit/827cb54919b7/Models/GLB-format/detail-crystal-large.glb"
const SWORD_URL = "https://game-assets.sitemills.com/library/kaykit/adventurers/49ac36d947cc/Assets/gltf/sword_1handed.glb"
const AXE_URL = "https://game-assets.sitemills.com/library/kaykit/adventurers/49ac36d947cc/Assets/gltf/axe_2handed.glb"

export const shell: GameShellConfig = {
  title: "Border Keep",
  subtitle: "Harvest gleaming crystal veins, muster a garrison of soldiers, and storm the central Raider stronghold.",
  modes: [
    {
      id: "skirmish",
      name: "Border Skirmish",
      description: "1–4 commanders build corner keeps and crush the central Raider camp.",
      minPlayers: 1,
      maxPlayers: 4,
    },
  ],
  howToPlay: [
    "Click or drag a box to select Workers and Soldiers; WASD, mouse wheel, or drag pans the tactical camera.",
    "Right-click a Gold Mine with Workers to gather gold, train units on the left, and right-click the Raider Camp with Soldiers to win.",
  ],
  controls: [
    { keys: "Left Click / Drag", action: "Select units" },
    { keys: "Right Click", action: "Move, gather, or attack" },
    { keys: "WASD / Arrows", action: "Pan camera" },
    { keys: "Scroll Wheel", action: "Zoom camera" },
    { keys: "Tab", action: "Scoreboard" },
    { keys: "Esc", action: "Pause & Settings" },
  ],
}

const START_GOLD = 50
const GOLD_PER_TRIP = 10
const WORKER_COST = 50
const TRAIN_SECONDS = 3
const SOLDIER_COST = 60
/** Each kind of unit: its health, its speed, and what one of its strikes takes (workers don't fight). */
const KINDS = { Worker: { health: 60, speed: 14, damage: 0 }, Soldier: { health: 150, speed: 14, damage: 20 }, Raider: { health: 80, speed: 12, damage: 12 } }
type Kind = keyof typeof KINDS
/** How near a fighter must be to strike, how far it sees an enemy, and the seconds between its strikes. */
const REACH = 6
const SIGHT = 32
const STRIKE_EVERY = 0.8
const HALL_HEALTH = 600
const CAMP_HEALTH = 800
/** The raiders' owner (players' units have their player's UserId), when their first raid sets out, and how often after. */
const RAIDERS = 0
const RAID_FIRST = 45
const RAID_EVERY = 40
/** A player's most units, and the most one order can move. */
const MAX_UNITS = 40
const COLOURS = [Color3.fromRGB(60, 120, 230), Color3.fromRGB(220, 60, 60), Color3.fromRGB(70, 180, 90), Color3.fromRGB(230, 190, 50)]
/** Where each player's town hall goes (a corner each), and its gold mine (toward the middle). */
const BASES = [new Vector3(-140, 0, -140), new Vector3(140, 0, 140), new Vector3(140, 0, -140), new Vector3(-140, 0, 140)]

export const place: EnginePlace = ({
  Workspace,
  Players,
  ReplicatedStorage,
  StarterGui,
  PhysicsService,
  PathfindingService,
  CollectionService,
  Lighting,
  Debris,
  task,
}) => {
  Lighting.ClockTime = 14.5
  new Instance("Sky", Lighting)
  Players.CharacterAutoLoads = false
  PhysicsService.RegisterCollisionGroup("Units")
  PhysicsService.CollisionGroupSetCollidable("Units", "Units", false)

  const part = (name: string, size: Vector3, at: Vector3, color: Color3, parent: Instance = Workspace, material = Enum.Material.SmoothPlastic) => {
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
  const meshDeco = (name: string, meshId: string, size: Vector3, cf: CFrame, parent: Instance, collide = false) => {
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
    m.Parent = parent
    return m
  }

  // The map: grass, rocky outcrops, pine groves, and a gleaming gold-crystal mine near each corner keep.
  part("Ground", new Vector3(400, 2, 400), new Vector3(0, -1, 0), Color3.fromRGB(98, 146, 74), Workspace, Enum.Material.Grass)
  for (let i = 0; i < 18; i++) {
    const angle = i * 2.4
    const r = 40 + (i % 6) * 22
    const size = 6 + (i % 3) * 4
    meshDeco(
      "Rock",
      BOULDER_URL,
      new Vector3(size, size * 0.65, size),
      new CFrame(Math.cos(angle) * r, size * 0.32, Math.sin(angle) * r).mul(CFrame.Angles(0, i * 0.9, 0)),
      Workspace,
      true,
    )
  }
  for (let clump = 0; clump < 8; clump++) {
    const angle = clump * 0.785 + 0.4
    const centre = new Vector3(Math.cos(angle) * 120, 0, Math.sin(angle) * 120)
    for (let i = 0; i < 6; i++) {
      const at = centre.add(new Vector3(Math.cos(i * 2.1) * (4 + i * 2), 0, Math.sin(i * 2.1) * (4 + i * 2)))
      const tall = i % 2 === 0
      const h = tall ? 18 : 15
      meshDeco(
        "Tree",
        tall ? TALL_PINE_URL : PINE_URL,
        new Vector3(5.6, h, 5.6),
        new CFrame(at.X, h / 2, at.Z).mul(CFrame.Angles(0, i * 1.3, 0)),
        Workspace,
        true,
      )
    }
  }
  const mines = BASES.map((base) => {
    const at = base.mul(0.62)
    const mine = part("GoldMine", new Vector3(10, 6, 10), new Vector3(at.X, 3, at.Z), Color3.fromRGB(220, 175, 48), Workspace, Enum.Material.Slate)
    meshDeco("GoldVein", CRYSTAL_URL, new Vector3(8.5, 6.2, 8.5), new CFrame(at.X, 5.2, at.Z), mine, false)
    CollectionService.AddTag(mine, "GoldMine")
    return mine
  })

  const command = new Instance("RemoteEvent")
  command.Name = "Command"
  command.Parent = ReplicatedStorage

  // Fighting -----------------------------------------------------------------------------------------------------------

  const fighters = new Set<Model>()
  const aims = new Map<Model, Model>()
  const marching = new Set<Model>()
  const trekking = new Set<Model>()
  const struck = new Map<Model, number>()
  const swings = new Map<Model, AnimationTrack>()
  const buildings = new Set<Model>()
  const withHealth = (building: Model, health: number) => {
    building.SetAttribute("Health", health)
    building.SetAttribute("MaxHealth", health)
    const bar = new Instance("BillboardGui", building.FindFirstChild("Base"))
    bar.Name = "HealthBar"
    bar.Size = UDim2.fromOffset(120, 12)
    bar.StudsOffset = new Vector3(0, 14, 0)
    const back = new Instance("Frame", bar)
    back.Size = UDim2.fromScale(1, 1)
    back.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
    back.BorderSizePixel = 0
    const fill = new Instance("Frame", back)
    fill.Name = "Fill"
    fill.Size = UDim2.fromScale(1, 1)
    fill.BackgroundColor3 = Color3.fromRGB(90, 210, 110)
    fill.BorderSizePixel = 0
    buildings.add(building)
  }
  const isBuilding = (thing: Model) => buildings.has(thing)
  const alive = (thing: Model) => !!thing.Parent && (isBuilding(thing) ? (thing.GetAttribute("Health") as number) > 0 : (thing.FindFirstChildOfClass("Humanoid")?.Health ?? 0) > 0)
  const placeOf = (thing: Model) => (isBuilding(thing) ? thing.GetPivot().Position : ((thing.FindFirstChild("HumanoidRootPart") as BasePart | undefined)?.Position ?? thing.GetPivot().Position))
  const girth = (thing: Model) => {
    if (!isBuilding(thing)) return 0
    const size = thing.GetExtentsSize()
    return Math.hypot(size.X, size.Z) / 2
  }
  const gapTo = (from: Vector3, thing: Model) => {
    const at = placeOf(thing)
    return Math.hypot(at.X - from.X, at.Z - from.Z) - girth(thing)
  }
  const slash = new Instance("Animation")
  slash.AnimationId = "toolslash"

  let campDown = false
  const fall = (building: Model) => {
    const owner = building.GetAttribute("Owner") as number
    const blast = new Instance("Explosion")
    blast.Position = building.GetPivot().Position
    blast.BlastRadius = 16
    blast.BlastPressure = 0
    blast.DestroyJointRadiusPercent = 0
    blast.Parent = Workspace
    buildings.delete(building)
    building.Destroy()
    if (owner === RAIDERS) {
      campDown = true
      for (const unit of CollectionService.GetTagged("Unit")) {
        if (unit.GetAttribute("Owner") === RAIDERS) ((unit as Model).FindFirstChildOfClass("Humanoid") as Humanoid).Health = 0
      }
      for (const player of halls.keys()) player.SetAttribute("Result", "Victory")
      return
    }
    const player = Players.GetPlayerByUserId(owner)
    if (!player) return
    halls.delete(player)
    player.SetAttribute("Result", "Defeat")
  }
  const hurt = (target: Model, damage: number) => {
    const humanoid = target.FindFirstChildOfClass("Humanoid")
    if (humanoid) {
      humanoid.TakeDamage(damage)
      return
    }
    const left = Math.max(0, (target.GetAttribute("Health") as number) - damage)
    target.SetAttribute("Health", left)
    const fill = target.FindFirstChild("Base")?.FindFirstChild("HealthBar")?.FindFirstChild("Frame")?.FindFirstChild("Fill") as Frame | undefined
    if (fill) fill.Size = UDim2.fromScale(left / (target.GetAttribute("MaxHealth") as number), 1)
    if (left === 0) fall(target)
  }

  // Each player's corner, keep, units and stats.
  const slots = new Map<Player, number>()
  const halls = new Map<Player, Model>()
  const stat = (player: Player, name: string) => player.FindFirstChild("leaderstats")?.FindFirstChild(name) as IntValue | undefined
  const unitsOf = (player: Player) => CollectionService.GetTagged("Unit").filter((u) => u.GetAttribute("Owner") === player.UserId && u.Parent) as Model[]
  const countUnits = (player: Player) => {
    const units = stat(player, "Units")
    if (units) units.Value = unitsOf(player).length
  }

  const makeHall = (player: Player, slot: number) => {
    const hall = new Instance("Model")
    hall.Name = "TownHall"
    const at = BASES[slot]
    part("Base", new Vector3(18, 8, 18), new Vector3(at.X, 4, at.Z), Color3.fromRGB(186, 176, 160), hall, Enum.Material.Cobblestone)
    part("Roof", new Vector3(20, 2, 20), new Vector3(at.X, 9, at.Z), COLOURS[slot], hall, Enum.Material.WoodPlanks)
    meshDeco("KeepTower", KEEP_TOWER_URL, new Vector3(12, 11, 12), new CFrame(at.X, 14.5, at.Z), hall, false)
    meshDeco("KeepRoof", KEEP_ROOF_URL, new Vector3(12, 14, 12), new CFrame(at.X, 24, at.Z), hall, false)
    meshDeco("KeepFlag", KEEP_FLAG_URL, new Vector3(1.1, 7.5, 4.8), new CFrame(at.X + 7, 13.5, at.Z), hall, false)
    hall.SetAttribute("Owner", player.UserId)
    CollectionService.AddTag(hall, "TownHall")
    withHealth(hall, HALL_HEALTH)
    hall.Parent = Workspace
    return hall
  }

  /** A unit of a kind for an owner (a player's UserId, or the raiders), in the owner's colour. Fighters carry a 3D blade. */
  const makeUnit = (kind: Kind, owner: number, colour: Color3, at: Vector3) => {
    const unit = defaultCharacter(kind)
    if (kind !== "Worker") {
      const arm = unit.FindFirstChild("Right Arm") as BasePart
      const blade = new Instance("MeshPart")
      blade.Name = "Blade"
      blade.MeshId = kind === "Soldier" ? SWORD_URL : AXE_URL
      blade.Size = kind === "Soldier" ? new Vector3(0.8, 3.2, 0.4) : new Vector3(1.8, 3.2, 0.5)
      blade.CanCollide = false
      blade.Massless = true
      blade.Parent = arm
      const hold = new Instance("Weld")
      hold.Part0 = arm
      hold.Part1 = blade
      hold.C0 = new CFrame(0, -1, -1.1).mul(CFrame.Angles(-Math.PI / 2, 0, 0))
      hold.Parent = arm
    }
    for (const d of unit.GetDescendants()) {
      if (!d.IsA("BasePart")) continue
      const p = d as BasePart
      p.CollisionGroup = "Units"
      if (p.Name === "Torso") p.Color = colour
      if (p.Name !== "HumanoidRootPart") {
        p.CanTouch = false
        p.CanQuery = false
      }
    }
    unit.PivotTo(new CFrame(at.X, 3, at.Z))
    unit.SetAttribute("Owner", owner)
    unit.SetAttribute("Kind", kind)
    CollectionService.AddTag(unit, "Unit")
    const humanoid = unit.FindFirstChildOfClass("Humanoid") as Humanoid
    humanoid.MaxHealth = KINDS[kind].health
    humanoid.Health = KINDS[kind].health
    humanoid.WalkSpeed = KINDS[kind].speed
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    humanoid.Died.Connect(() => {
      Debris.AddItem(unit, 2)
      const player = Players.GetPlayerByUserId(owner)
      if (player) task.delay(2.1, () => countUnits(player))
    })
    unit.Parent = Workspace
    if (kind !== "Worker") fighters.add(unit)
    const player = Players.GetPlayerByUserId(owner)
    if (player) countUnits(player)
    return unit
  }
  const makeWorker = (player: Player, at: Vector3) => makeUnit("Worker", player.UserId, COLOURS[slots.get(player) as number], at)

  const jobs = new Map<Model, number>()
  let nextJob = 0
  const startJob = (unit: Model) => {
    const job = ++nextJob
    jobs.set(unit, job)
    return () => jobs.get(unit) === job && !!unit.Parent
  }

  const walkTo = async (unit: Model, goal: Vector3, current: () => boolean) => {
    const humanoid = unit.FindFirstChildOfClass("Humanoid") as Humanoid
    const root = unit.FindFirstChild("HumanoidRootPart") as BasePart
    const path = PathfindingService.CreatePath({ AgentRadius: 2, AgentHeight: 5 })
    await path.ComputeAsync(root.Position, goal)
    const points = path.Status === Enum.PathStatus.Success ? path.GetWaypoints().map((w) => w.Position) : [goal]
    for (const point of points) {
      if (!current()) return false
      humanoid.MoveTo(point)
      const reached = await new Promise<boolean>((done) => {
        const c = humanoid.MoveToFinished.Connect((ok) => {
          c.Disconnect()
          done(ok)
        })
      })
      if (!reached) break
    }
    const left = goal.sub(root.Position)
    return current() && Math.hypot(left.X, left.Z) < 4
  }

  const beside = (centre: Vector3, size: Vector3, from: Vector3) => {
    const toward = new Vector3(from.X - centre.X, 0, from.Z - centre.Z).Unit
    return new Vector3(centre.X, 0, centre.Z).add(toward.mul(Math.hypot(size.X, size.Z) / 2 + 3))
  }

  const gather = async (player: Player, unit: Model, mine: BasePart) => {
    const current = startJob(unit)
    const hall = halls.get(player)
    while (current() && hall?.Parent) {
      const home = hall.GetPivot().Position
      if (!(await walkTo(unit, beside(mine.Position, mine.Size, home), current))) return
      await task.wait(1)
      if (!current()) return
      unit.SetAttribute("Carrying", GOLD_PER_TRIP)
      if (!(await walkTo(unit, beside(home, hall.GetExtentsSize(), mine.Position), current))) return
      const gold = stat(player, "Gold")
      if (gold) gold.Value += unit.GetAttribute("Carrying") as number
      unit.SetAttribute("Carrying", undefined)
    }
  }

  const trek = async (unit: Model, target: Model) => {
    if (trekking.has(unit)) return
    trekking.add(unit)
    const current = startJob(unit)
    const from = (unit.FindFirstChild("HumanoidRootPart") as BasePart).Position
    const size = isBuilding(target) ? target.GetExtentsSize() : new Vector3(0, 0, 0)
    await walkTo(unit, beside(placeOf(target), size, from), current)
    trekking.delete(unit)
  }

  const fight = async () => {
    for (;;) {
      await task.wait(0.4)
      const now = Workspace.DistributedGameTime
      const units = CollectionService.GetTagged("Unit") as Model[]
      for (const unit of [...fighters]) {
        const humanoid = unit.FindFirstChildOfClass("Humanoid")
        const root = unit.FindFirstChild("HumanoidRootPart") as BasePart | undefined
        if (!unit.Parent || !humanoid || !root || humanoid.Health <= 0) {
          fighters.delete(unit)
          aims.delete(unit)
          marching.delete(unit)
          trekking.delete(unit)
          struck.delete(unit)
          swings.delete(unit)
          continue
        }
        const owner = unit.GetAttribute("Owner")
        const enemy = (other: Model) => other !== unit && other.GetAttribute("Owner") !== owner && alive(other)
        const nearest = (within: number, andBuildings: boolean) => {
          let found: Model | undefined
          let best = within
          for (const other of andBuildings ? [...units, ...buildings] : units) {
            if (!enemy(other)) continue
            const gap = gapTo(root.Position, other)
            if (gap < best) {
              best = gap
              found = other
            }
          }
          return found
        }
        let target = nearest(REACH + 4, false)
        if (!target) {
          const aim = aims.get(unit)
          if (aim && alive(aim)) target = aim
          else aims.delete(unit)
        }
        if (!target && !marching.has(unit)) target = nearest(SIGHT, true)
        if (!target) continue
        const gap = gapTo(root.Position, target)
        if (gap > SIGHT) {
          void trek(unit, target)
          continue
        }
        jobs.set(unit, ++nextJob)
        if (gap > REACH) {
          humanoid.MoveTo(placeOf(target))
          continue
        }
        humanoid.MoveTo(root.Position)
        if (now - (struck.get(unit) ?? -9) < STRIKE_EVERY) continue
        struck.set(unit, now)
        let swing = swings.get(unit)
        if (!swing) {
          swing = humanoid.LoadAnimation(slash)
          swings.set(unit, swing)
        }
        swing.Play()
        hurt(target, KINDS[unit.GetAttribute("Kind") as Kind].damage)
      }
    }
  }
  void fight()

  // The raiders: a hexagonal stone bastion in the middle of the map with two guards, and raids at the keeps.
  const camp = new Instance("Model")
  camp.Name = "RaiderCamp"
  part("Base", new Vector3(16, 7, 16), new Vector3(0, 3.5, 0), Color3.fromRGB(78, 68, 68), camp, Enum.Material.Slate)
  part("Roof", new Vector3(18, 2, 18), new Vector3(0, 8, 0), Color3.fromRGB(165, 42, 42), camp, Enum.Material.Fabric)
  meshDeco("Bastion", RAIDER_BASTION_URL, new Vector3(11, 13, 10), new CFrame(0, 14.5, 0), camp, false)
  meshDeco("BastionRoof", RAIDER_ROOF_URL, new Vector3(12, 9, 11), new CFrame(0, 23, 0), camp, false)
  meshDeco("RaiderTent", TENT_URL, new Vector3(5.5, 4.8, 5.5), new CFrame(-4.5, 11.4, 4.5), camp, false)
  camp.SetAttribute("Owner", RAIDERS)
  CollectionService.AddTag(camp, "RaiderCamp")
  withHealth(camp, CAMP_HEALTH)
  camp.Parent = Workspace
  const raiderColour = Color3.fromRGB(120, 30, 30)
  const raiderAt = (i: number) => new Vector3(Math.cos(i * 1.3) * 16, 0, Math.sin(i * 1.3) * 16)
  for (let i = 0; i < 2; i++) makeUnit("Raider", RAIDERS, raiderColour, raiderAt(i * 2.4))
  const raids = async () => {
    await task.wait(RAID_FIRST)
    for (let n = 0; !campDown; n++) {
      for (let i = 0; i < Math.min(8, 2 + n); i++) {
        const raider = makeUnit("Raider", RAIDERS, raiderColour, raiderAt(i))
        let hall: Model | undefined
        for (const h of halls.values()) if (alive(h) && (!hall || gapTo(raiderAt(i), h) < gapTo(raiderAt(i), hall))) hall = h
        if (!hall) continue
        aims.set(raider, hall)
        void trek(raider, hall)
      }
      await task.wait(RAID_EVERY)
    }
  }
  let raiding = false

  Players.PlayerAdded.Connect((player) => {
    const stats = new Instance("Folder")
    stats.Name = "leaderstats"
    const gold = new Instance("IntValue", stats)
    gold.Name = "Gold"
    gold.Value = START_GOLD
    new Instance("IntValue", stats).Name = "Units"
    stats.Parent = player
    const taken = new Set(slots.values())
    const slot = [0, 1, 2, 3].find((s) => !taken.has(s))
    if (slot === undefined) return
    slots.set(player, slot)
    const hall = makeHall(player, slot)
    halls.set(player, hall)
    const home = BASES[slot]
    const out = home.mul(-1).Unit
    for (let i = 0; i < 3; i++) makeWorker(player, home.add(out.mul(16)).add(new Vector3((i - 1) * 4, 0, 0)))
    if (!raiding) {
      raiding = true
      void raids()
    }
  })

  Players.PlayerRemoving.Connect((player) => {
    for (const unit of unitsOf(player)) unit.Destroy()
    const hall = halls.get(player)
    if (hall) buildings.delete(hall)
    hall?.Destroy()
    halls.delete(player)
    slots.delete(player)
  })

  command.OnServerEvent.Connect((player, kind, units, target) => {
    if (kind === "train" || kind === "trainSoldier") {
      const gold = stat(player, "Gold")
      const hall = halls.get(player)
      const cost = kind === "train" ? WORKER_COST : SOLDIER_COST
      if (!gold || !hall || gold.Value < cost || unitsOf(player).length >= MAX_UNITS) return
      gold.Value -= cost
      task.delay(TRAIN_SECONDS, () => {
        if (!hall.Parent) return
        const at = hall.GetPivot().Position
        const out = at.mul(-1).Unit
        const turn = unitsOf(player).length * 2.4
        const spot = at.add(out.mul(14)).add(new Vector3(Math.cos(turn) * 3, 0, Math.sin(turn) * 3))
        if (kind === "train") makeWorker(player, spot)
        else makeUnit("Soldier", player.UserId, COLOURS[slots.get(player) as number], spot)
      })
      return
    }
    if (kind !== "move" || !Array.isArray(units) || !(target instanceof Vector3)) return
    const mine = new Set(unitsOf(player))
    const ordered = ([...new Set(units)] as Model[]).filter((u) => mine.has(u)).slice(0, MAX_UNITS)
    const goldMine = mines.find((m) => m.Position.sub(new Vector3(target.X, m.Position.Y, target.Z)).Magnitude < 9)
    let foe: Model | undefined
    for (const thing of [...(CollectionService.GetTagged("Unit") as Model[]), ...buildings]) {
      if (thing.GetAttribute("Owner") !== player.UserId && alive(thing) && gapTo(target, thing) < 5) foe = thing
    }
    const side = Math.ceil(Math.sqrt(ordered.length))
    ordered.forEach((unit, i) => {
      if (goldMine && unit.GetAttribute("Kind") === "Worker") {
        void gather(player, unit, goldMine)
        return
      }
      const soldier = unit.GetAttribute("Kind") === "Soldier"
      if (foe && soldier) {
        marching.delete(unit)
        aims.set(unit, foe)
        return
      }
      const offset = new Vector3((i % side) * 4 - (side - 1) * 2, 0, Math.floor(i / side) * 4 - (side - 1) * 2)
      const current = startJob(unit)
      aims.delete(unit)
      trekking.delete(unit)
      if (soldier) marching.add(unit)
      void walkTo(unit, target.add(offset), current).then(() => {
        if (jobs.get(unit) === undefined || !current()) return
        marching.delete(unit)
      })
    })
  })

  // The HUD. With no character, StarterGui isn't copied into PlayerGui (as in Roblox): the client script copies it.
  const hud = new Instance("ScreenGui")
  hud.Name = "Hud"
  const label = (name: string, y: number, text: string) => {
    const l = new Instance("TextLabel", hud)
    l.Name = name
    l.Size = UDim2.fromOffset(160, 34)
    l.Position = UDim2.fromOffset(16, y)
    l.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
    l.BackgroundTransparency = 0.25
    l.BorderSizePixel = 0
    l.TextColor3 = Color3.fromRGB(255, 255, 255)
    l.Font = Enum.Font.GothamBold
    l.TextSize = 16
    l.Text = text
    new Instance("UICorner", l).CornerRadius = new UDim(0, 10)
    return l
  }
  label("Gold", 16, "Gold: 0").TextColor3 = Color3.fromRGB(255, 215, 80)
  label("Units", 56, "Units: 0")
  label("Selected", 96, "Selected: 0")
  const train = new Instance("TextButton", hud)
  train.Name = "Train"
  train.Size = UDim2.fromOffset(160, 40)
  train.Position = UDim2.fromOffset(16, 136)
  train.BackgroundColor3 = Color3.fromRGB(60, 120, 230)
  train.TextColor3 = Color3.fromRGB(255, 255, 255)
  train.Font = Enum.Font.GothamBold
  train.TextSize = 16
  train.Text = `Train worker (${WORKER_COST})`
  new Instance("UICorner", train).CornerRadius = new UDim(0, 10)
  const soldier = train.Clone()
  soldier.Name = "TrainSoldier"
  soldier.Position = UDim2.fromOffset(16, 182)
  soldier.BackgroundColor3 = Color3.fromRGB(200, 70, 60)
  soldier.Text = `Train soldier (${SOLDIER_COST})`
  soldier.Parent = hud
  const result = label("Result", 0, "")
  result.AnchorPoint = new Vector2(0.5, 0.5)
  result.Position = UDim2.fromScale(0.5, 0.4)
  result.Size = UDim2.fromOffset(420, 90)
  result.TextSize = 54
  result.Visible = false
  const help = label("Help", 0, "Click or drag: select · Right-click or tap: send (a gold mine: gather, an enemy: attack) · WASD, wheel, drag: view")
  help.AnchorPoint = new Vector2(0.5, 1)
  help.Size = new UDim2(1, -32, 0, 44)
  help.Position = new UDim2(0.5, 0, 1, -12)
  help.TextSize = 14
  help.TextWrapped = true
  help.Font = Enum.Font.Gotham
  const box = new Instance("Frame", hud)
  box.Name = "SelectBox"
  box.Visible = false
  box.BackgroundColor3 = Color3.fromRGB(120, 200, 255)
  box.BackgroundTransparency = 0.8
  box.BorderSizePixel = 0
  new Instance("UIStroke", box).Color = Color3.fromRGB(120, 200, 255)
  hud.Parent = StarterGui
}
```

### `server/game/tests.ts`

```ts
// The game's own tests: they run on every build. testGame plays the place on a test server, and each player who joins
// is a client running the game's client script, as their page does. Time passes with `await t.wait(seconds)`.
import { describe, expect, test } from "../../api/test-framework.js"
import { Vector3, testGame, type BasePart, type IntValue, type Model, type RemoteEvent, type TextLabel } from "../framework/index"
import { client } from "./client"
import { place } from "./place"

describe("the strategy game", () => {
  test("a player has no character, a town hall and three workers; workers sent to the gold mine bring gold home", async () => {
    const t = await testGame(place, { client })
    const ana = t.join("Ana")
    await t.wait(1)
    expect(ana.serverPlayer.Character).toBe(undefined)
    const units = t.services.CollectionService.GetTagged("Unit").filter((u) => u.GetAttribute("Owner") === ana.serverPlayer.UserId) as Model[]
    expect(units.length).toBe(3)
    const gold = ana.serverPlayer.FindFirstChild("leaderstats")?.FindFirstChild("Gold") as IntValue
    expect(gold.Value).toBe(50)
    // Her client sends them to her mine (the one nearest her town hall), as a right click there does.
    const hall = t.services.CollectionService.GetTagged("TownHall").find((h) => h.GetAttribute("Owner") === ana.serverPlayer.UserId) as Model
    const mine = (t.services.CollectionService.GetTagged("GoldMine") as BasePart[]).sort((a, b) => a.Position.sub(hall.GetPivot().Position).Magnitude - b.Position.sub(hall.GetPivot().Position).Magnitude)[0]
    const command = ana.mirror(t.services.ReplicatedStorage.FindFirstChild("Command") as RemoteEvent) as RemoteEvent
    command.FireServer("move", units.map((u) => ana.mirror(u)), mine.Position)
    await t.wait(20)
    expect(gold.Value >= 50 + 3 * 10).toBe(true)
    // Her client's HUD shows it.
    expect(ana.player?.FindFirstChild("PlayerGui")?.FindFirstChild("Hud")?.FindFirstChild("Gold")?.Name).toBe("Gold")
  })

  test("the town hall trains a worker for 50 gold; units sent to one spot all get there (they pass through each other)", async () => {
    const t = await testGame(place, { client })
    const ana = t.join("Ana")
    await t.wait(1)
    const command = ana.mirror(t.services.ReplicatedStorage.FindFirstChild("Command") as RemoteEvent) as RemoteEvent
    const stats = ana.serverPlayer.FindFirstChild("leaderstats") as Model
    command.FireServer("train")
    await t.wait(4)
    expect((stats.FindFirstChild("Gold") as IntValue).Value).toBe(0)
    expect((stats.FindFirstChild("Units") as IntValue).Value).toBe(4)
    command.FireServer("train")
    await t.wait(4)
    expect((stats.FindFirstChild("Units") as IntValue).Value).toBe(4)
    const units = t.services.CollectionService.GetTagged("Unit").filter((u) => u.GetAttribute("Owner") === ana.serverPlayer.UserId) as Model[]
    // Open ground near her town hall (nothing but the ground within 8 studs).
    const spot = new Vector3(-100, 0, -140)
    expect(t.services.Workspace.GetPartBoundsInRadius(new Vector3(spot.X, 3, spot.Z), 8).filter((p) => p.Name !== "Ground").length).toBe(0)
    command.FireServer("move", units.map((u) => ana.mirror(u)), spot)
    await t.wait(6)
    for (const unit of units) {
      const at = (unit.FindFirstChild("HumanoidRootPart") as BasePart).Position
      expect(Math.hypot(at.X - spot.X, at.Z - spot.Z) < 6).toBe(true)
    }
  })

  test("soldiers sent at the raiders' camp fight its guards, then bring it down: a victory", async () => {
    const t = await testGame(place, { client })
    const ana = t.join("Ana")
    await t.wait(1)
    const command = ana.mirror(t.services.ReplicatedStorage.FindFirstChild("Command") as RemoteEvent) as RemoteEvent
    const mine = (u: { GetAttribute(name: string): unknown }) => u.GetAttribute("Owner") === ana.serverPlayer.UserId
    const raiders = () => t.services.CollectionService.GetTagged("Unit").filter((u) => u.GetAttribute("Kind") === "Raider" && u.Parent)
    const camp = t.services.CollectionService.GetTagged("RaiderCamp")[0] as Model
    expect(raiders().length).toBe(2)
    expect(camp.GetAttribute("Health")).toBe(800)
    // Gold for three soldiers (60 each), trained at her town hall.
    const gold = ana.serverPlayer.FindFirstChild("leaderstats")?.FindFirstChild("Gold") as IntValue
    gold.Value = 180
    for (let i = 0; i < 3; i++) command.FireServer("trainSoldier")
    await t.wait(4)
    expect(gold.Value).toBe(0)
    const soldiers = t.services.CollectionService.GetTagged("Unit").filter((u) => mine(u) && u.GetAttribute("Kind") === "Soldier") as Model[]
    expect(soldiers.length).toBe(3)
    // Sent at the camp (a right click on it): they walk there, cut down its guards, and strike it until it falls.
    command.FireServer("move", soldiers.map((u) => ana.mirror(u)), camp.GetPivot().Position)
    await t.wait(22)
    expect((camp.GetAttribute("Health") as number) < 800).toBe(true)
    await t.wait(16)
    expect(camp.Parent).toBe(undefined)
    expect(raiders().length).toBe(0)
    expect(ana.serverPlayer.GetAttribute("Result")).toBe("Victory")
    // Her page shows it.
    expect((ana.player?.FindFirstChild("PlayerGui")?.FindFirstChild("Hud")?.FindFirstChild("Result") as TextLabel).Text).toBe("VICTORY")
  })

  test("a player can't order another player's units", async () => {
    const t = await testGame(place, { client })
    const ana = t.join("Ana")
    const bob = t.join("Bob")
    await t.wait(1)
    const anas = t.services.CollectionService.GetTagged("Unit").filter((u) => u.GetAttribute("Owner") === ana.serverPlayer.UserId) as Model[]
    const before = anas.map((u) => (u.FindFirstChild("HumanoidRootPart") as BasePart).Position)
    const command = bob.mirror(t.services.ReplicatedStorage.FindFirstChild("Command") as RemoteEvent) as RemoteEvent
    command.FireServer("move", anas.map((u) => bob.mirror(u)), new Vector3(0, 0, 0))
    await t.wait(3)
    anas.forEach((u, i) => expect((u.FindFirstChild("HumanoidRootPart") as BasePart).Position.sub(before[i]).Magnitude < 1).toBe(true))
    // When she leaves, her units and town hall go.
    ana.leave()
    await t.wait(1)
    expect(t.services.CollectionService.GetTagged("Unit").filter((u) => u.GetAttribute("Owner") === ana.serverPlayer.UserId).length).toBe(0)
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
