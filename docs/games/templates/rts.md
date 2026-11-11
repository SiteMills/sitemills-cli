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
// Strategy: a map seen from above, and no avatar. Each player who joins gets a town hall and three workers in a corner
// of the map. Workers sent to a gold mine gather from it and carry the gold home; the town hall trains more workers.
// - Players.CharacterAutoLoads is false, so players have no character. The client script flies a Scriptable camera
//   over the map, selects units (a click, or a box dragged around them) and sends orders through the Command remote.
// - Units are NPCs the server moves (Humanoid.MoveTo, around rocks with PathfindingService). They're in the "Units"
//   collision group, which doesn't collide with itself, so a crowd of them passes through itself instead of jamming.
// - The server checks every order: a player orders only their own units.
// - Fighting: the town hall also trains soldiers. Sent at an enemy (a unit or a building), they walk there and strike
//   it; left alone, they strike any enemy that comes in sight. Raiders hold a camp in the middle of the map and send
//   raids at the town halls. A town hall that falls is a defeat for its player; the camp falling is a victory.
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
  type Humanoid,
  type IntValue,
  type Model,
  type Player,
} from "../framework/index"

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

export const place: EnginePlace = ({ Workspace, Players, ReplicatedStorage, StarterGui, PhysicsService, PathfindingService, CollectionService, Lighting, Debris, task }) => {
  Lighting.ClockTime = 14
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

  // The map: grass, rocks in the way, and a gold mine near each base.
  part("Ground", new Vector3(400, 2, 400), new Vector3(0, -1, 0), Color3.fromRGB(104, 150, 76), Workspace, Enum.Material.Grass)
  for (let i = 0; i < 18; i++) {
    const angle = i * 2.4
    const r = 40 + (i % 6) * 22
    const size = 6 + (i % 3) * 4
    part("Rock", new Vector3(size, size * 0.7, size), new Vector3(Math.cos(angle) * r, size * 0.35, Math.sin(angle) * r), Color3.fromRGB(120, 116, 110), Workspace, Enum.Material.Slate)
  }
  // Trees in clumps (in the way, as the rocks are): a trunk and a crown each.
  for (let clump = 0; clump < 8; clump++) {
    const angle = clump * 0.785 + 0.4
    const centre = new Vector3(Math.cos(angle) * 120, 0, Math.sin(angle) * 120)
    for (let i = 0; i < 6; i++) {
      const at = centre.add(new Vector3(Math.cos(i * 2.1) * (4 + i * 2), 0, Math.sin(i * 2.1) * (4 + i * 2)))
      const tree = new Instance("Model")
      tree.Name = "Tree"
      part("Trunk", new Vector3(1.6, 8, 1.6), new Vector3(at.X, 4, at.Z), Color3.fromRGB(110, 80, 50), tree, Enum.Material.Wood)
      const crown = part("Crown", new Vector3(8, 8, 8), new Vector3(at.X, 10, at.Z), Color3.fromRGB(56, 120, 60), tree, Enum.Material.Grass)
      crown.Shape = Enum.PartType.Ball
      tree.Parent = Workspace
    }
  }
  const mines = BASES.map((base) => {
    const at = base.mul(0.62)
    const mine = part("GoldMine", new Vector3(10, 6, 10), new Vector3(at.X, 3, at.Z), Color3.fromRGB(240, 190, 40), Workspace, Enum.Material.Neon)
    CollectionService.AddTag(mine, "GoldMine")
    return mine
  })

  const command = new Instance("RemoteEvent")
  command.Name = "Command"
  command.Parent = ReplicatedStorage

  // Fighting -----------------------------------------------------------------------------------------------------------

  /** The units that fight, what each was sent at, those walking where they were sent (they don't pick fights on the
   *  way), and those on a long walk to what they were sent at. */
  const fighters = new Set<Model>()
  const aims = new Map<Model, Model>()
  const marching = new Set<Model>()
  const trekking = new Set<Model>()
  const struck = new Map<Model, number>()
  const swings = new Map<Model, AnimationTrack>()
  /** Town halls and the raiders' camp: each has Health and MaxHealth attributes, and a bar over it. */
  const buildings = new Set<Model>()
  const withHealth = (building: Model, health: number) => {
    building.SetAttribute("Health", health)
    building.SetAttribute("MaxHealth", health)
    const bar = new Instance("BillboardGui", building.FindFirstChild("Base"))
    bar.Name = "HealthBar"
    bar.Size = UDim2.fromOffset(120, 12)
    bar.StudsOffset = new Vector3(0, 12, 0)
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
  /** How far a building reaches from its middle (a unit: not at all). */
  const girth = (thing: Model) => {
    if (!isBuilding(thing)) return 0
    const size = thing.GetExtentsSize()
    return Math.hypot(size.X, size.Z) / 2
  }
  /** The ground between a point and the nearest of a thing. */
  const gapTo = (from: Vector3, thing: Model) => {
    const at = placeOf(thing)
    return Math.hypot(at.X - from.X, at.Z - from.Z) - girth(thing)
  }
  const slash = new Instance("Animation")
  slash.AnimationId = "toolslash"

  /** A building at no health falls: a town hall is its player's defeat; the camp is everyone's victory, and its raiders fall with it. */
  let campDown = false
  const fall = (building: Model) => {
    const owner = building.GetAttribute("Owner") as number
    // It goes up in a blast (for show: it hurts nothing).
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

  // Each player's corner, town hall, units and stats.
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
    part("Base", new Vector3(18, 8, 18), new Vector3(at.X, 4, at.Z), Color3.fromRGB(200, 180, 150), hall, Enum.Material.Brick)
    part("Roof", new Vector3(20, 3, 20), new Vector3(at.X, 9.5, at.Z), COLOURS[slot], hall, Enum.Material.WoodPlanks)
    hall.SetAttribute("Owner", player.UserId)
    CollectionService.AddTag(hall, "TownHall")
    withHealth(hall, HALL_HEALTH)
    hall.Parent = Workspace
    return hall
  }

  /** A unit of a kind for an owner (a player's UserId, or the raiders), in the owner's colour. Fighters carry a blade. */
  const makeUnit = (kind: Kind, owner: number, colour: Color3, at: Vector3) => {
    const unit = defaultCharacter(kind)
    if (kind !== "Worker") {
      // In its right hand, joined to the arm (so it swings with it).
      const arm = unit.FindFirstChild("Right Arm") as BasePart
      const blade = new Instance("Part")
      blade.Name = "Blade"
      blade.Size = new Vector3(0.3, 0.3, 3)
      blade.Color = kind === "Soldier" ? Color3.fromRGB(210, 215, 225) : Color3.fromRGB(70, 60, 60)
      blade.Material = Enum.Material.Metal
      blade.CanCollide = false
      blade.Massless = true
      blade.CFrame = arm.CFrame.mul(new CFrame(0, -0.9, -1.3))
      blade.Parent = arm
      const hold = new Instance("WeldConstraint")
      hold.Part0 = arm
      hold.Part1 = blade
      hold.Parent = arm
    }
    for (const d of unit.GetDescendants()) {
      if (!d.IsA("BasePart")) continue
      const p = d as BasePart
      p.CollisionGroup = "Units"
      if (p.Name === "Torso") p.Color = colour
      // Only drawn: the root's shape is what collides and what a click hits, so the rest costs no collider.
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
    // Many units close together: no name tags over them.
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    // It falls where it dies, and is cleared away.
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

  // What each unit is doing: a new order replaces its job, and the old one stops at its next step.
  const jobs = new Map<Model, number>()
  let nextJob = 0
  const startJob = (unit: Model) => {
    const job = ++nextJob
    jobs.set(unit, job)
    return () => jobs.get(unit) === job && !!unit.Parent
  }

  /** Walks a unit to a point, around rocks, until it's there (within 4 studs) or the job's over. A MoveTo that hasn't
   *  got there in 8 seconds (stuck) gives up, as in Roblox. */
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

  /** Where a unit stands to reach a building: outside its footprint, on the side toward `from`. */
  const beside = (centre: Vector3, size: Vector3, from: Vector3) => {
    const toward = new Vector3(from.X - centre.X, 0, from.Z - centre.Z).Unit
    return new Vector3(centre.X, 0, centre.Z).add(toward.mul(Math.hypot(size.X, size.Z) / 2 + 3))
  }

  /** A worker's trips: to the mine, a second's digging, home with the gold, and again, until it's given another order. */
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

  /** A long walk to what a fighter was sent at (round the rocks). Once it's in sight, the fight below takes over. */
  const trek = async (unit: Model, target: Model) => {
    if (trekking.has(unit)) return
    trekking.add(unit)
    const current = startJob(unit)
    const from = (unit.FindFirstChild("HumanoidRootPart") as BasePart).Position
    const size = isBuilding(target) ? target.GetExtentsSize() : new Vector3(0, 0, 0)
    await walkTo(unit, beside(placeOf(target), size, from), current)
    trekking.delete(unit)
  }

  /** The fight, a few times a second: each fighter picks who to strike, walks up, and strikes. */
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
        // Whoever is on it comes first; then what it was sent at; then, unless it's walking where it was sent, the
        // nearest enemy in sight.
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
        // Near enough to see it: straight at it, and whatever walk it was on is over.
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

  // The raiders: a camp in the middle of the map with two guards, and raids at the town halls, bigger each time.
  const camp = new Instance("Model")
  camp.Name = "RaiderCamp"
  part("Base", new Vector3(16, 7, 16), new Vector3(0, 3.5, 0), Color3.fromRGB(70, 60, 60), camp, Enum.Material.Slate)
  part("Roof", new Vector3(18, 2, 18), new Vector3(0, 8, 0), Color3.fromRGB(170, 40, 40), camp, Enum.Material.Fabric)
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
        // At the town hall nearest the camp that's still standing.
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
    // Up to four players get a corner; others watch.
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
        // In front of the hall, each new one a little round from the last (a spiral, so they don't land on each other).
        const turn = unitsOf(player).length * 2.4
        const spot = at.add(out.mul(14)).add(new Vector3(Math.cos(turn) * 3, 0, Math.sin(turn) * 3))
        if (kind === "train") makeWorker(player, spot)
        else makeUnit("Soldier", player.UserId, COLOURS[slots.get(player) as number], spot)
      })
      return
    }
    if (kind !== "move" || !Array.isArray(units) || !(target instanceof Vector3)) return
    // Only the player's own units, and each once.
    const mine = new Set(unitsOf(player))
    const ordered = ([...new Set(units)] as Model[]).filter((u) => mine.has(u)).slice(0, MAX_UNITS)
    // Sent to a gold mine: workers gather from it. Anywhere else: they go there in a block, 4 studs apart.
    const goldMine = mines.find((m) => m.Position.sub(new Vector3(target.X, m.Position.Y, target.Z)).Magnitude < 9)
    // Sent at an enemy (a unit or a building, under the point): soldiers go and strike it.
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
  // Victory or defeat, across the middle (the client script shows it).
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
  // The box dragged to select (the client script shows and sizes it).
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
import { engineRoom } from "../framework/index"
import { place } from "../game/place"

// The game's server: a room runs the place, and each player who opens the page joins it.
sdk.registerRoom("game", engineRoom(place, { maxPlayers: 16 }))
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
import { joinRoom } from "@/api/room-client"
import { playOnline, playSolo } from "@/framework/index"
import { client } from "../../server/game/client"
import { place } from "../../server/game/place"

/**
 * The game. Everyone who opens the page plays together in a room (server/rooms/game_room.ts runs the place there);
 * with ?solo in the address, it plays alone in the page. With ?debug, window.__game is the game's view (its engine,
 * localPlayer and, alone, the server's engine) for checking it from the browser console or a test.
 */
export function GamePage() {
  const canvas = useRef<HTMLCanvasElement>(null)
  const [problem, setProblem] = useState<string | null>(null)
  useEffect(() => {
    let stop: (() => void) | null = null
    let gone = false
    void (async () => {
      await RAPIER.init()
      if (gone || !canvas.current) return
      const solo = new URLSearchParams(window.location.search).has("solo")
      const game = solo
        ? await playSolo({ canvas: canvas.current, physics: RAPIER, place, client })
        : await playOnline({ canvas: canvas.current, physics: RAPIER, client, room: await joinRoom("game", { roomId: "auto" }) })
      if (gone) game.stop()
      else stop = () => game.stop()
      if (new URLSearchParams(window.location.search).has("debug")) (window as unknown as { __game: unknown }).__game = game
    })().catch((error: unknown) => setProblem(error instanceof Error ? error.message : String(error)))
    return () => {
      gone = true
      stop?.()
    }
  }, [])
  return (
    <div className="relative h-svh w-full select-none overflow-hidden bg-black">
      <canvas ref={canvas} className="block h-full w-full" />
      {problem && <div className="absolute inset-x-0 top-4 mx-auto w-fit max-w-[90%] rounded-lg bg-red-600 px-4 py-2 text-sm text-white">{problem}</div>}
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
