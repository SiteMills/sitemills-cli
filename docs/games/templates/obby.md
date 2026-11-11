# Starter game: Obby

A 3D obstacle course in the sky: jumps, lava back to the last checkpoint, a moving platform and a spinner. Stages are kept between visits, and the finish records each player's best time.

Template `obby`, on SiteMills game framework 1.0 (release 1.0.0). [The Games Guide](../../GAMES_GUIDE.md) says how to make it your game.

## Start from it

With the CLI, in one step:

```bash
sitemills-cli game create "My Game" --template obby
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
// The game's client script: the HUD's stage, and the time when this player reaches the finish (the server tells only
// them, through the Finished RemoteEvent).
import type { ClientScript, IntValue, RemoteEvent, TextLabel } from "../framework/index"

export const client: ClientScript = ({ player, RunService, ReplicatedStorage, task }) => {
  const hud = () => player.PlayerGui?.FindFirstChild("Hud")
  RunService.RenderStepped.Connect(() => {
    const stage = player.FindFirstChild("leaderstats")?.FindFirstChild("Stage") as IntValue | undefined
    const label = hud()?.FindFirstChild("Stage") as TextLabel | undefined
    if (label) label.Text = `Stage ${stage?.Value ?? 0}`
  })
  const finished = ReplicatedStorage.FindFirstChild("Finished") as RemoteEvent
  finished.OnClientEvent.Connect((seconds, previous) => {
    const label = hud()?.FindFirstChild("Time") as TextLabel | undefined
    if (!label) return
    label.Text = previous === undefined || (seconds as number) < (previous as number) ? `Finished in ${seconds}s, a best!` : `Finished in ${seconds}s (best ${previous}s)`
    label.Visible = true
    task.delay(6, () => (label.Visible = false))
  })
}
```

### `server/game/place.ts`

```ts
// Obby: an obstacle course in the sky. Platforms with gaps, lava that sends you back to your last checkpoint, a moving
// platform and a spinner; each checkpoint (a SpawnLocation) is a stage, kept between visits; the finish records each
// player's best time in an ordered DataStore, and tells their client (a RemoteEvent) for the HUD.
import { CFrame, Color3, Enum, Instance, TweenInfo, UDim, UDim2, Vector3, type BasePart, type EnginePlace, type IntValue, type Player, type SpawnLocation } from "../framework/index"

export const place: EnginePlace = ({ Workspace, Lighting, Players, ReplicatedStorage, StarterGui, TweenService, RunService, DataStoreService }) => {
  Lighting.ClockTime = 9
  Workspace.FallenPartsDestroyHeight = -60

  const block = (size: Vector3, at: Vector3, color: Color3, material = Enum.Material.SmoothPlastic) => {
    const p = new Instance("Part")
    p.Anchored = true
    p.Size = size
    p.Position = at
    p.Color = color
    p.Material = material
    p.Parent = Workspace
    return p
  }
  const lava = (size: Vector3, at: Vector3) => {
    const p = block(size, at, Color3.fromRGB(255, 70, 30), Enum.Material.Neon)
    p.Name = "Lava"
    p.Touched.Connect((hit) => {
      const humanoid = hit.Parent?.FindFirstChildOfClass("Humanoid")
      if (humanoid) humanoid.Health = 0
    })
    return p
  }

  // Stages, each ending in a checkpoint. A player's stage is kept, and they come back at their checkpoint.
  const saves = DataStoreService.GetDataStore("Stage")
  const checkpoints: SpawnLocation[] = []
  const checkpoint = (stage: number, at: Vector3) => {
    const c = new Instance("SpawnLocation")
    c.Name = `Stage${stage}`
    c.Size = new Vector3(10, 1, 10)
    c.Position = at
    c.Color = Color3.fromRGB(80, 200, 120)
    c.SetAttribute("Stage", stage)
    // Only the start is where new players appear; the others are where each player comes back.
    c.Enabled = stage === 0
    c.Parent = Workspace
    checkpoints[stage] = c
    c.Touched.Connect((hit) => {
      const player = Players.GetPlayerFromCharacter(hit.Parent)
      const reached = player?.FindFirstChild("leaderstats")?.FindFirstChild("Stage") as IntValue | undefined
      if (!player || !reached || reached.Value >= stage) return
      reached.Value = stage
      player.RespawnLocation = c
      void saves.SetAsync(String(player.UserId), stage)
    })
  }
  checkpoint(0, new Vector3(0, 20, 0))
  // Stage 1: jumps over a gap.
  for (let i = 0; i < 4; i++) block(new Vector3(6, 1, 6), new Vector3(0, 20, -12 - i * 11), Color3.fromRGB(240, 240, 250))
  checkpoint(1, new Vector3(0, 20, -60))
  // Stage 2: a lava floor with stepping stones.
  lava(new Vector3(10, 1, 30), new Vector3(0, 19.5, -80))
  for (let i = 0; i < 3; i++) block(new Vector3(3, 1, 3), new Vector3(i % 2 === 0 ? -2.5 : 2.5, 21, -70 - i * 8), Color3.fromRGB(240, 240, 250))
  checkpoint(2, new Vector3(0, 20, -100))
  // Stage 3: a moving platform across a big gap, and a spinner beyond it.
  const mover = block(new Vector3(8, 1, 8), new Vector3(0, 20, -115), Color3.fromRGB(90, 140, 255))
  TweenService.Create(mover, new TweenInfo(3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { CFrame: new CFrame(0, 20, -145) }).Play()
  block(new Vector3(12, 1, 12), new Vector3(0, 20, -160), Color3.fromRGB(240, 240, 250))
  const spinner = block(new Vector3(22, 1, 1.5), new Vector3(0, 21.5, -160), Color3.fromRGB(255, 120, 40))
  spinner.Name = "Spinner"
  RunService.Heartbeat.Connect((dt) => (spinner.CFrame = spinner.CFrame.mul(CFrame.Angles(0, dt * 1.6, 0))))
  spinner.Touched.Connect((hit) => {
    const root = hit.Parent?.FindFirstChild("HumanoidRootPart") as BasePart | undefined
    if (root && hit.Parent?.FindFirstChildOfClass("Humanoid")) root.AssemblyLinearVelocity = new Vector3(0, 40, 30)
  })
  checkpoint(3, new Vector3(0, 20, -175))
  // The finish.
  const finish = block(new Vector3(14, 1, 14), new Vector3(0, 20, -195), Color3.fromRGB(255, 215, 60), Enum.Material.Neon)
  finish.Name = "Finish"

  // Times: from when a player's character spawns to the finish, which counts once they've reached the last
  // checkpoint. Best times go in an ordered DataStore (a leaderboard can list them with GetSortedAsync).
  const best = DataStoreService.GetOrderedDataStore("BestSeconds")
  const finished = new Instance("RemoteEvent")
  finished.Name = "Finished"
  finished.Parent = ReplicatedStorage
  const started = new Map<Player, number>()
  Players.PlayerAdded.Connect(async (player) => {
    const stats = new Instance("Folder")
    stats.Name = "leaderstats"
    const stage = new Instance("IntValue", stats)
    stage.Name = "Stage"
    stats.Parent = player
    player.CharacterAdded.Connect(() => started.set(player, Workspace.DistributedGameTime))
    stage.Value = ((await saves.GetAsync(String(player.UserId))) as number | undefined) ?? 0
    if (stage.Value > 0 && checkpoints[stage.Value]) {
      player.RespawnLocation = checkpoints[stage.Value]
      player.LoadCharacter()
    }
  })
  Players.PlayerRemoving.Connect((player) => started.delete(player))
  finish.Touched.Connect(async (hit) => {
    const player = Players.GetPlayerFromCharacter(hit.Parent)
    const from = player ? started.get(player) : undefined
    const reached = player?.FindFirstChild("leaderstats")?.FindFirstChild("Stage") as IntValue | undefined
    if (!player || from === undefined || !reached || reached.Value < checkpoints.length - 1) return
    // Each part of the character touches it: the first counts, and the next run starts when they spawn again.
    started.delete(player)
    const seconds = Math.round(Workspace.DistributedGameTime - from)
    const key = String(player.UserId)
    const previous = (await best.GetAsync(key)) as number | undefined
    if (previous === undefined || seconds < previous) await best.SetAsync(key, seconds)
    // Over the network, undefined and null both arrive as undefined (Roblox's nil).
    finished.FireClient(player, seconds, previous)
  })

  // The HUD: the stage, and the time after the finish (the client script fills them in).
  const hud = new Instance("ScreenGui")
  hud.Name = "Hud"
  const label = (name: string, y: number) => {
    const l = new Instance("TextLabel", hud)
    l.Name = name
    l.Size = UDim2.fromOffset(260, 40)
    l.Position = UDim2.fromOffset(16, y)
    l.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
    l.BackgroundTransparency = 0.3
    l.BorderSizePixel = 0
    l.TextColor3 = Color3.fromRGB(255, 255, 255)
    l.Font = Enum.Font.GothamBold
    l.TextSize = 20
    l.Text = ""
    new Instance("UICorner", l).CornerRadius = new UDim(0, 10)
    return l
  }
  label("Stage", 16).Text = "Stage 0"
  label("Time", 64).Visible = false
  hud.Parent = StarterGui
}
```

### `server/game/tests.ts`

```ts
// The game's own tests: they run on every build. testGame plays the place on a test server, and each player who joins
// is a client running the game's client script, as their page does. Time passes with `await t.wait(seconds)`.
import { describe, expect, test } from "../../api/test-framework.js"
import { CFrame, Vector3, testGame, type BasePart, type Humanoid, type IntValue, type Model, type TextLabel } from "../framework/index"
import { client } from "./client"
import { place } from "./place"

const stand = (character: Model, on: BasePart) => character.PivotTo(new CFrame(on.Position.add(new Vector3(0, on.Size.Y / 2 + 3, 0))))

describe("the obby", () => {
  test("a checkpoint is where a player comes back after lava, and their stage is kept", async () => {
    const t = await testGame(place, { client })
    const ana = t.join("Ana", 5)
    await t.wait(1)
    const ws = t.services.Workspace
    stand(ana.serverPlayer.Character as Model, ws.FindFirstChild("Stage1") as BasePart)
    await t.wait(0.5)
    const stage = ana.serverPlayer.FindFirstChild("leaderstats")?.FindFirstChild("Stage") as IntValue
    expect(stage.Value).toBe(1)
    const hud = ana.player?.FindFirstChild("PlayerGui")?.FindFirstChild("Hud")?.FindFirstChild("Stage") as TextLabel
    expect(hud.Text).toBe("Stage 1")
    // Lava kills; the new character is at Stage1.
    stand(ana.serverPlayer.Character as Model, ws.FindFirstChild("Lava") as BasePart)
    await t.wait(0.5)
    expect((ana.serverPlayer.Character?.FindFirstChildOfClass("Humanoid") as Humanoid).Health).toBe(0)
    await t.wait(t.services.Players.RespawnTime + 0.5)
    const root = ana.serverPlayer.Character?.FindFirstChild("HumanoidRootPart") as BasePart
    expect(root.Position.sub((ws.FindFirstChild("Stage1") as BasePart).Position).Magnitude).toBeLessThan(8)
    // Next visit: still stage 1, and back at its checkpoint.
    ana.leave()
    await t.wait(0.5)
    const again = t.join("Ana", 5)
    await t.wait(1)
    expect((again.serverPlayer.FindFirstChild("leaderstats")?.FindFirstChild("Stage") as IntValue).Value).toBe(1)
    const back = again.serverPlayer.Character?.FindFirstChild("HumanoidRootPart") as BasePart
    expect(back.Position.sub((ws.FindFirstChild("Stage1") as BasePart).Position).Magnitude).toBeLessThan(8)
  })

  test("the finish counts after the last checkpoint, and tells the player their time", async () => {
    const t = await testGame(place, { client })
    const ana = t.join("Ana")
    await t.wait(1)
    const ws = t.services.Workspace
    const time = () => ana.player?.FindFirstChild("PlayerGui")?.FindFirstChild("Hud")?.FindFirstChild("Time") as TextLabel
    // Straight to the finish: it doesn't count.
    stand(ana.serverPlayer.Character as Model, ws.FindFirstChild("Finish") as BasePart)
    await t.wait(0.5)
    expect(time().Visible).toBe(false)
    stand(ana.serverPlayer.Character as Model, ws.FindFirstChild("Stage3") as BasePart)
    await t.wait(1)
    stand(ana.serverPlayer.Character as Model, ws.FindFirstChild("Finish") as BasePart)
    await t.wait(0.5)
    expect(time().Visible).toBe(true)
    expect(time().Text).toBe("Finished in 3s, a best!")
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
