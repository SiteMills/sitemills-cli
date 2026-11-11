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
// Open world: a town to walk and drive around. Coins to collect (kept between visits in a DataStore), a car anyone can
// drive (its VehicleSeat's Throttle and Steer turn its wheel motors), a shop with a ProximityPrompt that sells speed,
// and townsfolk walking between places along paths (PathfindingService).
import {
  CFrame,
  Color3,
  Enum,
  Instance,
  UDim,
  UDim2,
  Vector3,
  defaultCharacter,
  type BasePart,
  type EnginePlace,
  type HingeConstraint,
  type Humanoid,
  type IntValue,
} from "../framework/index"

export const place: EnginePlace = ({ Workspace, Lighting, Players, StarterGui, RunService, DataStoreService, PathfindingService, task }) => {
  Lighting.ClockTime = 16

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

  // The town: grass, two crossing roads, houses along them.
  part("Grass", new Vector3(400, 2, 400), new Vector3(0, -1, 0), Color3.fromRGB(96, 160, 72), Enum.Material.Grass)
  part("RoadNS", new Vector3(24, 0.2, 400), new Vector3(0, 0.1, 0), Color3.fromRGB(60, 60, 66), Enum.Material.Asphalt)
  part("RoadEW", new Vector3(400, 0.2, 24), new Vector3(0, 0.12, 0), Color3.fromRGB(60, 60, 66), Enum.Material.Asphalt)
  const colours = [Color3.fromRGB(230, 200, 160), Color3.fromRGB(190, 120, 100), Color3.fromRGB(150, 180, 210), Color3.fromRGB(220, 220, 220)]
  let n = 0
  for (const x of [-60, -30, 30, 60]) {
    for (const z of [-60, 60]) {
      const house = new Instance("Model")
      house.Name = `House${++n}`
      part("Walls", new Vector3(18, 12, 18), new Vector3(x, 6, z), colours[n % colours.length], Enum.Material.Brick, house)
      part("Roof", new Vector3(20, 2, 20), new Vector3(x, 13, z), Color3.fromRGB(120, 60, 50), Enum.Material.WoodPlanks, house)
      house.Parent = Workspace
    }
  }
  const spawn = new Instance("SpawnLocation")
  spawn.Position = new Vector3(-20, 0.5, -20)
  spawn.Parent = Workspace

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
  const coinAt = (at: Vector3) => {
    const coin = new Instance("Part")
    coin.Name = "Coin"
    coin.Anchored = true
    coin.CanCollide = false
    coin.Shape = Enum.PartType.Cylinder
    coin.Size = new Vector3(0.4, 3, 3)
    coin.CFrame = new CFrame(at.X, at.Y, at.Z)
    coin.Color = Color3.fromRGB(255, 205, 50)
    coin.Material = Enum.Material.Neon
    coin.Parent = Workspace
    spinning.add(coin)
    coin.Touched.Connect((hit) => {
      const player = Players.GetPlayerFromCharacter(hit.Parent)
      const coins = player?.FindFirstChild("leaderstats")?.FindFirstChild("Coins") as IntValue | undefined
      if (!coins || !coin.Parent) return
      coins.Value += 1
      coin.Destroy()
      // A new one somewhere else, a little later.
      task.delay(5, () => coinAt(new Vector3((Math.random() - 0.5) * 160, 2.5, (Math.random() - 0.5) * 160)))
    })
  }
  // Coins turn as they wait (a Heartbeat turns each a little every frame).
  const spinning = new Set<BasePart>()
  RunService.Heartbeat.Connect((dt) => {
    for (const coin of spinning) {
      if (!coin.Parent) spinning.delete(coin)
      else coin.CFrame = coin.CFrame.mul(CFrame.Angles(0, dt * 2, 0))
    }
  })
  for (let i = 0; i < 12; i++) coinAt(new Vector3((i % 4) * 14 - 21, 2.5, Math.floor(i / 4) * 14 - 40))

  // The shop: a counter with a ProximityPrompt. 10 coins buy speed.
  const shop = part("Shop", new Vector3(8, 4, 4), new Vector3(20, 2, -20), Color3.fromRGB(80, 140, 230))
  const prompt = new Instance("ProximityPrompt", shop)
  prompt.ActionText = "Buy speed"
  prompt.ObjectText = "10 coins"
  prompt.Triggered.Connect((player) => {
    const coins = player.FindFirstChild("leaderstats")?.FindFirstChild("Coins") as IntValue | undefined
    const humanoid = player.Character?.FindFirstChildOfClass("Humanoid") as Humanoid | undefined
    if (!coins || !humanoid || coins.Value < 10) return
    coins.Value -= 10
    humanoid.WalkSpeed = 26
  })

  // A car: a chassis on four motorised wheels, and a VehicleSeat. Its Throttle and Steer drive the wheels.
  const car = new Instance("Model")
  car.Name = "Car"
  const chassis = part("Chassis", new Vector3(6, 1, 10), new Vector3(-8, 3, 20), Color3.fromRGB(220, 50, 50), Enum.Material.SmoothPlastic, car)
  chassis.Anchored = false
  const seat = new Instance("VehicleSeat")
  seat.Position = new Vector3(-8, 4, 20)
  seat.Parent = car
  const weld = new Instance("WeldConstraint", seat)
  weld.Part0 = chassis
  weld.Part1 = seat
  const wheels: HingeConstraint[] = []
  for (const [x, z] of [[-3.6, -3], [3.6, -3], [-3.6, 3], [3.6, 3]]) {
    const wheel = new Instance("Part")
    wheel.Name = "Wheel"
    wheel.Shape = Enum.PartType.Cylinder
    wheel.Size = new Vector3(1, 3, 3)
    wheel.Position = new Vector3(-8 + x, 2, 20 + z)
    wheel.Color = Color3.fromRGB(30, 30, 30)
    wheel.Parent = car
    const a0 = new Instance("Attachment", chassis)
    a0.Position = new Vector3(x, -1, z)
    const a1 = new Instance("Attachment", wheel)
    const hinge = new Instance("HingeConstraint", chassis)
    hinge.Attachment0 = a0
    hinge.Attachment1 = a1
    hinge.ActuatorType = Enum.ActuatorType.Motor
    hinge.MotorMaxTorque = 1e5
    wheels.push(hinge)
  }
  car.Parent = Workspace
  seat.Changed.Connect((property) => {
    if (property !== "ThrottleFloat" && property !== "SteerFloat") return
    // Forward is the seat's look (-Z), and a positive wheel speed rolls toward +Z. Steering turns one side faster.
    wheels.forEach((hinge, i) => {
      const left = i % 2 === 0
      hinge.AngularVelocity = -seat.ThrottleFloat * 16 + seat.SteerFloat * (left ? -6 : 6)
    })
  })

  // Townsfolk: each walks to a place and on to the next, along a path around the houses.
  const places = [new Vector3(-40, 0, -40), new Vector3(40, 0, -40), new Vector3(40, 0, 40), new Vector3(-40, 0, 40)]
  for (let i = 0; i < 2; i++) {
    const walker = defaultCharacter(`Townsperson${i + 1}`)
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
