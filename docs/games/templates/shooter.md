# Starter game: Wave shooter

A first-person shooter: waves of zombies come at the players in a walled yard with cover; each player has a blaster. Kills and each player's best wave (kept between visits) are on the leaderboard.

Template `shooter`, on SiteMills game framework 1.0 (release 1.0.0). [The Games Guide](../../GAMES_GUIDE.md) says how to make it your game.

## Start from it

With the CLI, in one step:

```bash
sitemills-cli game create "My Game" --template shooter
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
// The game's client script: first person with the mouse locked (a click on the game captures it; Esc frees it), and
// the HUD's wave, zombies left and health.
import { Enum, type ClientScript, type TextLabel } from "../framework/index"

export const client: ClientScript = ({ player, Workspace, RunService, UserInputService }) => {
  player.CameraMode = Enum.CameraMode.LockFirstPerson
  UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
  const text = (name: string, value: string) => {
    const label = player.PlayerGui?.FindFirstChild("Hud")?.FindFirstChild(name) as TextLabel | undefined
    if (label && label.Text !== value) label.Text = value
  }
  RunService.RenderStepped.Connect(() => {
    const wave = (Workspace.GetAttribute("Wave") as number | undefined) ?? 0
    text("Wave", wave === 0 ? "Get ready" : `Wave ${wave}`)
    text("Left", `Zombies left: ${(Workspace.GetAttribute("Left") as number | undefined) ?? 0}`)
    const humanoid = player.Character?.FindFirstChildOfClass("Humanoid")
    text("Health", `Health: ${Math.ceil(humanoid?.Health ?? 0)}`)
  })
}
```

### `server/game/place.ts`

```ts
// Shooter: survive waves of zombies in a fortified courtyard.
// - Every player has a blaster (a Tool in StarterPack, copied into each Backpack). A click hurts the zombie they aimed
//   at (player.GetMouse().Target, their client's view), if it's in range and nothing solid is between.
// - Zombies are clones of a 3D animated template in ServerStorage. Each walks at the nearest player (around cover
//   crates with PathfindingService when it can't see them) and strikes when close.
// - A cleared wave starts a bigger one. Kills and a player's best wave are leaderstats; the best wave is kept in an
//   ordered DataStore. The wave and the zombies left are attributes on Workspace, for the HUD.
import {
  CFrame,
  Color3,
  ColorSequence,
  Enum,
  Instance,
  NumberRange,
  NumberSequence,
  RaycastParams,
  UDim,
  UDim2,
  Vector2,
  Vector3,
  modelCharacter,
  type BasePart,
  type EnginePlace,
  type GameShellConfig,
  type Humanoid,
  type IntValue,
  type Model,
  type Motor6D,
  type Player,
  type PointLight,
  type Sound,
  type Tool,
} from "../framework/index"

const DEFENDER_URL = "https://game-assets.sitemills.com/library/kenney/blocky-characters/960fb9d7961f/Models/GLB-format/character-m.glb"
const ZOMBIE_URL = "https://game-assets.sitemills.com/library/kenney/mini-dungeon/0b0b44e6d2bc/Models/GLB-format/character-orc.glb"
const BLASTER_URL = "https://game-assets.sitemills.com/library/kenney/blaster-kit/bda17d928fa2/Models/GLB-format/blaster-d.glb"
const CRATE_URL = "https://game-assets.sitemills.com/library/kenney/prototype-kit/e61e26421cef/Models/GLB-format/crate-color.glb"
const CARGO_URL = "https://game-assets.sitemills.com/library/kenney/space-station-kit/e87a95009d27/Models/GLB-format/container.glb"
const TOWER_BASE_URL = "https://game-assets.sitemills.com/library/kenney/castle-kit/a2095edf1a6e/Models/GLB-format/tower-square-base.glb"
const TOWER_ROOF_URL = "https://game-assets.sitemills.com/library/kenney/castle-kit/a2095edf1a6e/Models/GLB-format/tower-square-roof.glb"
const BANNER_URL = "https://game-assets.sitemills.com/library/kenney/castle-kit/a2095edf1a6e/Models/GLB-format/flag-banner-long.glb"
const SHOT_SOUND_URL = "https://game-assets.sitemills.com/library/kenney/sci-fi-sounds/aa1026bb4c50/Audio/laserSmall_000.ogg"
const BITE_SOUND_URL = "https://game-assets.sitemills.com/library/kenney/impact-sounds/0a420c43ff99/Audio/impactPunch_medium_000.ogg"
const CLEAR_SOUND_URL = "https://game-assets.sitemills.com/library/kenney/synth-voice-2/1aa97678ca2a/Audio/victory.ogg"

export const shell: GameShellConfig = {
  title: "Bastion Holdout",
  subtitle: "Defend the stone courtyard against escalating waves, use supply crates as cover, and climb the wall leaderboard.",
  modes: [
    {
      id: "coop-holdout",
      name: "Co-op Holdout",
      description: "1–8 defenders survive escalating waves together.",
      minPlayers: 1,
      maxPlayers: 8,
    },
    {
      id: "solo-holdout",
      name: "Solo Stand",
      description: "Hold the courtyard alone for a personal wave record.",
      minPlayers: 1,
      maxPlayers: 1,
    },
  ],
  howToPlay: [
    "Equip your Blaster (1 key or backpack tap) and click or tap incoming raiders to fire.",
    "Shots knock enemies back; kite around crates and clear every wave to push your best score higher.",
  ],
}

export const place: EnginePlace = ({
  Workspace,
  Lighting,
  Players,
  StarterPlayer,
  ServerStorage,
  StarterPack,
  StarterGui,
  CollectionService,
  PathfindingService,
  DataStoreService,
  Debris,
  task,
}) => {
  // Late afternoon: golden low sun and crisp courtyard shadows.
  Lighting.ClockTime = 16.5
  new Instance("Sky", Lighting)

  const defender = modelCharacter("StarterCharacter", DEFENDER_URL, {
    idle: "idle",
    walk: "walk",
    run: "sprint",
    die: "die",
    wave: "emote-yes",
  })
  defender.Parent = StarterPlayer

  const block = (size: Vector3, at: Vector3, color: Color3, material = Enum.Material.Concrete) => {
    const p = new Instance("Part")
    p.Anchored = true
    p.Size = size
    p.Position = at
    p.Color = color
    p.Material = material
    p.Parent = Workspace
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

  // Courtyard stone floor, perimeter ramparts, corner watchtowers, and supply crates for cover.
  block(new Vector3(160, 2, 160), new Vector3(0, -1, 0), Color3.fromRGB(122, 118, 110), Enum.Material.Cobblestone)
  for (const [x, z, w, d] of [[0, 80, 160, 3], [0, -80, 160, 3], [80, 0, 3, 160], [-80, 0, 3, 160]]) {
    block(new Vector3(w, 14, d), new Vector3(x, 7, z), Color3.fromRGB(132, 120, 108), Enum.Material.Brick)
  }
  for (const [cx, cz] of [[-80, -80], [80, -80], [-80, 80], [80, 80]] as const) {
    meshProp("CornerTower", TOWER_BASE_URL, new Vector3(14, 16, 14), new CFrame(cx, 8, cz), false)
    meshProp("CornerRoof", TOWER_ROOF_URL, new Vector3(14, 22, 14), new CFrame(cx, 26, cz), false)
  }
  for (const side of [-22, 22]) {
    meshProp("WallBanner", BANNER_URL, new Vector3(0.6, 18, 5.2), new CFrame(side, 9, -78).mul(CFrame.Angles(0, Math.PI / 2, 0)), false)
  }
  const coverSpots: [number, number][] = [[-38, -16], [25, -35], [-40, 30], [35, 25], [0, 45], [22, -8]]
  coverSpots.forEach(([x, z], i) => {
    meshProp(
      "CoverCrate",
      i % 2 === 0 ? CARGO_URL : CRATE_URL,
      new Vector3(8, 6, 8),
      new CFrame(x, 3, z).mul(CFrame.Angles(0, (i % 4) * (Math.PI / 2), 0)),
      true,
    )
  })
  const spawn = new Instance("SpawnLocation")
  spawn.Size = new Vector3(12, 0.8, 12)
  spawn.Position = new Vector3(0, 0.4, 0)
  spawn.Color = Color3.fromRGB(185, 178, 164)
  spawn.Material = Enum.Material.Marble
  spawn.Parent = Workspace

  // Each player's stats; the best wave is loaded from (and saved to) an ordered store, so it can be a leaderboard.
  const bestWaves = DataStoreService.GetOrderedDataStore("BestWave")
  const stat = (player: Player, name: string) => player.FindFirstChild("leaderstats")?.FindFirstChild(name) as IntValue | undefined
  Players.PlayerAdded.Connect(async (player) => {
    const stats = new Instance("Folder")
    stats.Name = "leaderstats"
    new Instance("IntValue", stats).Name = "Kills"
    const best = new Instance("IntValue", stats)
    best.Name = "Best"
    stats.Parent = player
    best.Value = ((await bestWaves.GetAsync(String(player.UserId))) as number | undefined) ?? 0
    best.Changed.Connect(() => showBoard())
    showBoard()
  })

  // The blaster: a 3D sci-fi rifle MeshPart Handle with muzzle sound and flash.
  const blaster = new Instance("Tool")
  blaster.Name = "Blaster"
  blaster.AddTag("Blaster")
  blaster.Grip = CFrame.Angles(0, Math.PI, 0)
  const barrel = new Instance("MeshPart")
  barrel.Name = "Handle"
  barrel.MeshId = BLASTER_URL
  barrel.Size = new Vector3(0.7, 1.4, 3.2)
  barrel.Parent = blaster
  const bang = new Instance("Sound", barrel)
  bang.Name = "Shot"
  bang.SoundId = SHOT_SOUND_URL
  const flash = new Instance("PointLight", barrel)
  flash.Name = "Flash"
  flash.Color = Color3.fromRGB(255, 220, 120)
  flash.Brightness = 4
  flash.Range = 14
  flash.Enabled = false
  blaster.Parent = StarterPack

  /** A shove along the ground for a moment: a mover on its root, and it slides to a stop when the mover goes. */
  const shove = (root: BasePart, away: Vector3, speed: number, seconds: number) => {
    const flat = new Vector3(away.X, 0, away.Z)
    if (flat.Magnitude < 0.01) return
    const push = new Instance("BodyVelocity")
    push.Velocity = flat.Unit.mul(speed)
    push.MaxForce = new Vector3(Infinity, 0, Infinity)
    push.Parent = root
    Debris.AddItem(push, seconds)
  }
  // Sparks where a shot lands: one emitter for the yard, moved to each hit and burst there.
  const sparkPoint = new Instance("Part")
  sparkPoint.Name = "Sparks"
  sparkPoint.Anchored = true
  sparkPoint.CanCollide = false
  sparkPoint.CanQuery = false
  sparkPoint.CanTouch = false
  sparkPoint.Transparency = 1
  sparkPoint.Size = new Vector3(0.2, 0.2, 0.2)
  sparkPoint.Position = new Vector3(0, -20, 0)
  const burst = new Instance("ParticleEmitter", sparkPoint)
  burst.Enabled = false
  burst.Lifetime = new NumberRange(0.2, 0.4)
  burst.Speed = new NumberRange(8, 14)
  burst.SpreadAngle = new Vector2(180, 180)
  burst.Color = new ColorSequence(Color3.fromRGB(255, 225, 120), Color3.fromRGB(220, 90, 40))
  burst.Size = new NumberSequence(0.35, 0)
  sparkPoint.Parent = Workspace
  const sparks = (at: Vector3) => {
    sparkPoint.Position = at
    burst.Emit(10)
  }
  const lastShot = new Map<Tool, number>()
  const shoot = (tool: Tool) => {
    const player = Players.GetPlayerFromCharacter(tool.Parent)
    const head = player?.Character?.FindFirstChild("Head") as BasePart | undefined
    const handle = tool.Handle
    if (!player || !head || !handle) return
    const now = Workspace.DistributedGameTime
    if (now - (lastShot.get(tool) ?? -1) < 0.25) return
    lastShot.set(tool, now)
    const mouse = player.GetMouse()
    tracer(handle.Position, mouse.Hit.Position)
    ;(handle.FindFirstChild("Shot") as Sound | undefined)?.Play()
    const light = handle.FindFirstChild("Flash") as PointLight | undefined
    if (light) {
      light.Enabled = true
      task.delay(0.06, () => (light.Enabled = false))
    }
    // What the client says it hit is a claim: check it's a live zombie, in range, with nothing solid in between.
    const target = mouse.Target
    const zombie = target?.FindFirstAncestorOfClass("Model")
    const humanoid = zombie?.FindFirstChildOfClass("Humanoid")
    if (!target || !zombie || !humanoid || !zombie.HasTag("Zombie") || humanoid.Health <= 0) return
    const to = target.Position.sub(head.Position)
    if (to.Magnitude > 250) return
    const params = new RaycastParams()
    params.FilterDescendantsInstances = [player.Character as Model, zombie]
    const wall = Workspace.Raycast(head.Position, to, params)
    if (wall && wall.Instance.CanCollide) return
    humanoid.TakeDamage(34)
    sparks(mouse.Hit.Position)
    const hitRoot = zombie.FindFirstChild("HumanoidRootPart") as BasePart | undefined
    if (hitRoot) shove(hitRoot, hitRoot.Position.sub(head.Position), 18, 0.12)
    const kills = stat(player, "Kills")
    if (humanoid.Health <= 0 && kills) kills.Value += 1
  }
  const tracer = (from: Vector3, to: Vector3) => {
    const length = Math.min(to.sub(from).Magnitude, 250)
    if (length < 0.5) return
    const beam = new Instance("Part")
    beam.Anchored = true
    beam.CanCollide = false
    beam.CanQuery = false
    beam.CanTouch = false
    beam.Material = Enum.Material.Neon
    beam.Color = Color3.fromRGB(255, 220, 90)
    beam.Size = new Vector3(0.12, 0.12, length)
    beam.CFrame = new CFrame(from, to).mul(new CFrame(0, 0, -length / 2))
    beam.Parent = Workspace
    Debris.AddItem(beam, 0.08)
  }
  const wire = (tool: Tool) => tool.Activated.Connect(() => shoot(tool))
  for (const t of CollectionService.GetTagged("Blaster")) wire(t as Tool)
  CollectionService.GetInstanceAddedSignal("Blaster").Connect((t) => wire(t as Tool))

  // The zombie template: an animated 3D orc-raider character, slightly slower than a player.
  const template = modelCharacter("Zombie", ZOMBIE_URL, {
    idle: "idle",
    walk: "walk",
    run: "sprint",
    jump: "jump",
    fall: "fall",
    die: "die",
  })
  const zombieHumanoid = template.FindFirstChildOfClass("Humanoid") as Humanoid
  zombieHumanoid.WalkSpeed = 12
  template.AddTag("Zombie")
  template.Parent = ServerStorage

  const growl = new Instance("Sound", Workspace)
  growl.Name = "Bite"
  growl.SoundId = BITE_SOUND_URL
  const waveFanfare = new Instance("Sound", Workspace)
  waveFanfare.Name = "WaveCleared"
  waveFanfare.SoundId = CLEAR_SOUND_URL
  const biteAnim = new Instance("Animation")
  biteAnim.AnimationId = "attack-melee-right"

  const nearestCharacter = (from: Vector3) => {
    let best: BasePart | undefined
    for (const player of Players.GetPlayers()) {
      const root = player.Character?.FindFirstChild("HumanoidRootPart") as BasePart | undefined
      const alive = (player.Character?.FindFirstChildOfClass("Humanoid")?.Health ?? 0) > 0
      if (root && alive && (!best || root.Position.sub(from).Magnitude < best.Position.sub(from).Magnitude)) best = root
    }
    return best
  }
  const sight = new RaycastParams()
  const chase = async (zombie: Model) => {
    const humanoid = zombie.FindFirstChildOfClass("Humanoid") as Humanoid
    const root = zombie.FindFirstChild("HumanoidRootPart") as BasePart
    const strike = humanoid.LoadAnimation(biteAnim)
    const path = PathfindingService.CreatePath({ AgentRadius: 2, AgentHeight: 5, AgentCanJump: false })
    let bitAt = -1
    while (humanoid.Health > 0 && zombie.Parent) {
      const target = nearestCharacter(root.Position)
      if (target) {
        const gap = target.Position.sub(root.Position)
        sight.FilterDescendantsInstances = [zombie, target.Parent as Model]
        const blocked = Workspace.Raycast(root.Position, gap, sight)
        if (!blocked) humanoid.MoveTo(target.Position)
        else {
          await path.ComputeAsync(root.Position, target.Position)
          const waypoints = path.GetWaypoints()
          humanoid.MoveTo(path.Status === Enum.PathStatus.Success ? waypoints[Math.min(2, waypoints.length - 1)].Position : target.Position)
        }
        const victim = target.Parent?.FindFirstChildOfClass("Humanoid")
        const now = Workspace.DistributedGameTime
        if (victim && gap.Magnitude < 4.5 && now - bitAt > 1) {
          bitAt = now
          strike.Play()
          victim.TakeDamage(15)
          growl.Play()
          shove(target, gap, 22, 0.18)
        }
      }
      await task.wait(0.25)
    }
  }

  // Waves: 3 zombies, then 2 more each wave, from the yard's corners; the next starts 5 seconds after one is cleared.
  const corners = [new Vector3(-70, 3, -70), new Vector3(70, 3, -70), new Vector3(-70, 3, 70), new Vector3(70, 3, 70)]
  Workspace.SetAttribute("Wave", 0)
  Workspace.SetAttribute("Left", 0)
  const runWave = async (wave: number) => {
    Workspace.SetAttribute("Wave", wave)
    const count = 1 + wave * 2
    let left = count
    Workspace.SetAttribute("Left", left)
    for (let i = 0; i < count; i++) {
      const zombie = template.Clone()
      zombie.PivotTo(new CFrame(corners[i % corners.length].add(new Vector3((i % 3) * 4, 0, 0))))
      zombie.Parent = Workspace
      // Arms out in front on the underlying hit-rig, as zombies hold them.
      for (const [name, turn] of [["Right Shoulder", Math.PI / 2], ["Left Shoulder", -Math.PI / 2]] as const) {
        const shoulder = zombie.FindFirstChild("Torso")?.FindFirstChild(name) as Motor6D | undefined
        if (shoulder) shoulder.C0 = shoulder.C0.mul(CFrame.Angles(0, 0, turn))
      }
      const humanoid = zombie.FindFirstChildOfClass("Humanoid") as Humanoid
      humanoid.Died.Connect(() => {
        left -= 1
        Workspace.SetAttribute("Left", left)
        Debris.AddItem(zombie, 3)
        if (left === 0) void cleared(wave)
      })
      void chase(zombie)
      await task.wait(0.4)
    }
  }
  const cleared = async (wave: number) => {
    waveFanfare.Play()
    for (const player of Players.GetPlayers()) {
      const best = stat(player, "Best")
      if (best && wave > best.Value) {
        best.Value = wave
        await bestWaves.SetAsync(String(player.UserId), wave)
      }
    }
    await task.wait(5)
    void runWave(wave + 1)
  }

  // The scoreboard on the far wall, facing the spawn: the wave, the zombies left, and the players' best waves.
  const board = block(new Vector3(26, 9, 0.6), new Vector3(0, 8, -78.2), Color3.fromRGB(24, 26, 34), Enum.Material.Metal)
  board.Name = "Board"
  const screen = new Instance("SurfaceGui", board)
  screen.Face = Enum.NormalId.Back
  screen.CanvasSize = new Vector2(650, 225)
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
  const boardWave = line("Wave", 8, 100, Color3.fromRGB(255, 255, 255))
  const boardLeft = line("Left", 112, 50, Color3.fromRGB(255, 200, 90))
  const boardBest = line("Best", 168, 44, Color3.fromRGB(150, 220, 255))
  const showBoard = () => {
    const wave = (Workspace.GetAttribute("Wave") as number | undefined) ?? 0
    boardWave.Text = wave === 0 ? "GET READY" : `WAVE ${wave}`
    boardLeft.Text = `Zombies left: ${(Workspace.GetAttribute("Left") as number | undefined) ?? 0}`
    const best = Players.GetPlayers()
      .map((player) => ({ name: player.DisplayName || player.Name, wave: stat(player, "Best")?.Value ?? 0 }))
      .sort((a, b) => b.wave - a.wave)
      .slice(0, 3)
    boardBest.Text = best.length > 0 ? `Best: ${best.map((b) => `${b.name} ${b.wave}`).join("   ")}` : ""
  }
  Workspace.GetAttributeChangedSignal("Wave").Connect(showBoard)
  Workspace.GetAttributeChangedSignal("Left").Connect(showBoard)
  Players.PlayerRemoving.Connect(() => task.defer(showBoard))
  showBoard()
  let started = false
  Players.PlayerAdded.Connect(() => {
    if (started) return
    started = true
    task.delay(3, () => void runWave(1))
  })

  // The HUD: a crosshair, the wave, the zombies left, and health (the client script fills in the text).
  const hud = new Instance("ScreenGui")
  hud.Name = "Hud"
  const label = (name: string, y: number) => {
    const l = new Instance("TextLabel", hud)
    l.Name = name
    l.Size = UDim2.fromOffset(220, 36)
    l.Position = UDim2.fromOffset(16, y)
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
  label("Wave", 16)
  label("Left", 58)
  label("Health", 100)
  const crosshair = new Instance("Frame", hud)
  crosshair.Name = "Crosshair"
  crosshair.AnchorPoint = new Vector2(0.5, 0.5)
  crosshair.Position = UDim2.fromScale(0.5, 0.5)
  crosshair.Size = UDim2.fromOffset(6, 6)
  crosshair.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
  crosshair.BorderSizePixel = 0
  new Instance("UICorner", crosshair).CornerRadius = new UDim(0.5, 0)
  hud.Parent = StarterGui
}
```

### `server/game/tests.ts`

```ts
// The game's own tests: they run on every build. testGame plays the place on a test server, and each player who joins
// is a client running the game's client script, as their page does. Time passes with `await t.wait(seconds)`.
import { describe, expect, test } from "../../api/test-framework.js"
import { testGame, type BasePart, type Humanoid, type IntValue, type Model, type TextLabel, type Tool } from "../framework/index"
import { client } from "./client"
import { place } from "./place"

const zombies = (t: { services: { Workspace: Model } }) => t.services.Workspace.GetChildren().filter((c) => c.HasTag("Zombie")) as Model[]

describe("the shooter", () => {
  test("the first wave comes; zombies walk at the player; a blaster shot hurts one, and three kill it", async () => {
    const t = await testGame(place, { client })
    const ana = t.join("Ana")
    await t.wait(4.5)
    expect(t.services.Workspace.GetAttribute("Wave")).toBe(1)
    const wave = zombies(t)
    expect(wave.length).toBe(3)
    const zombie = wave[0]
    const root = ana.serverPlayer.Character?.FindFirstChild("HumanoidRootPart") as BasePart
    const zombieRoot = zombie.FindFirstChild("HumanoidRootPart") as BasePart
    const before = zombieRoot.Position.sub(root.Position).Magnitude
    await t.wait(1)
    expect(zombieRoot.Position.sub(root.Position).Magnitude).toBeLessThan(before - 5)
    // Ana's blaster: equip it, then click on the zombie.
    const blaster = ana.serverPlayer.FindFirstChildOfClass("Backpack")?.FindFirstChild("Blaster") as Tool
    ana.equip(blaster)
    await t.wait(0.3)
    const torso = zombie.FindFirstChild("Torso") as BasePart
    const humanoid = zombie.FindFirstChildOfClass("Humanoid") as Humanoid
    // It holds its arms out in front (its shoulders are turned), and the scoreboard on the wall has the wave.
    for (const arm of ["Right Arm", "Left Arm"]) expect(torso.CFrame.Inverse().mul((zombie.FindFirstChild(arm) as BasePart).CFrame).Z).toBeLessThan(-0.4)
    const boardText = (name: string) => (t.services.Workspace.FindFirstChild("Board")?.FindFirstChildOfClass("SurfaceGui")?.FindFirstChild(name) as TextLabel).Text
    expect(boardText("Wave")).toBe("WAVE 1")
    expect(boardText("Left")).toBe("Zombies left: 3")
    expect(boardText("Best")).toBe("Best: Ana 0")
    // A hit knocks it back (a mover on its root for a moment) and bursts sparks where it landed.
    let shoves = 0
    zombieRoot.ChildAdded.Connect((child) => {
      if (child.ClassName === "BodyVelocity") shoves += 1
    })
    ana.activate(blaster, torso)
    await t.wait(0.3)
    expect(shoves).toBe(1)
    expect(zombieRoot.FindFirstChildOfClass("BodyVelocity") === undefined).toBe(true)
    expect((t.services.Workspace.FindFirstChild("Sparks") as BasePart).Position.sub(torso.Position).Magnitude).toBeLessThan(3)
    expect(humanoid.Health).toBe(66)
    for (let i = 0; i < 2; i++) {
      ana.activate(blaster, torso)
      await t.wait(0.3)
    }
    expect(humanoid.Health).toBe(0)
    expect((ana.serverPlayer.FindFirstChild("leaderstats")?.FindFirstChild("Kills") as IntValue).Value).toBe(1)
    const left = ana.player?.FindFirstChild("PlayerGui")?.FindFirstChild("Hud")?.FindFirstChild("Left") as TextLabel
    expect(left.Text).toBe("Zombies left: 2")
    expect(boardText("Left")).toBe("Zombies left: 2")
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
  const [problem, setProblem] = useState<string | null>(null)
  useEffect(() => {
    let dispose: (() => void) | null = null
    let gone = false
    void (async () => {
      await RAPIER.init()
      if (gone || !canvas.current || !container.current) return
      const shellConfig = (gamePlace as { shell?: GameShellConfig }).shell
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
      else dispose = () => shell.dispose()
    })().catch((error: unknown) => setProblem(error instanceof Error ? error.message : String(error)))
    return () => {
      gone = true
      dispose?.()
    }
  }, [])
  return (
    <div ref={container} className="relative h-svh w-full select-none overflow-hidden bg-black">
      <canvas ref={canvas} className="block h-full w-full" />
      {problem && <div className="absolute inset-x-0 top-4 z-30 mx-auto w-fit max-w-[90%] rounded-lg bg-red-600 px-4 py-2 text-sm text-white">{problem}</div>}
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
