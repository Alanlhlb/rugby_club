# Rugby Union Basics 🏉

A brief guide to rugby rules and terminology relevant to this App.

---

## 1. Basic Rules

- Each team has **15 players** on the field: **8 Forwards** and **7 Backs**
- A match consists of **two 40-minute halves** (80 minutes total)
- The ball can only be **passed backwards**, but may be **kicked forwards**
- When a ball carrier is tackled to the ground, they must release the ball, forming a **Ruck**

---

## 2. Scoring

The App tracks four types of scoring for each player:

| Scoring Method | Points | Description |
|---------------|--------|-------------|
| **Try** | 5 | Grounding the ball in the opponent's in-goal area |
| **Conversion** | 2 | A kick at goal awarded after a try |
| **Penalty Kick** | 3 | A kick at goal awarded after an opponent's infringement |
| **Drop Goal** | 3 | A kick during open play where the ball bounces off the ground before being kicked |

> Total points formula in the App: `(Tries × 5) + (Conversions × 2) + (Penalties × 3) + (Drop Goals × 3)`

---

## 3. Player Positions (15-a-side)

### Forwards (Jersey #1–8)

| # | Position | Role |
|---|----------|------|
| 1 | Loosehead Prop | Left side of the scrum front row |
| 2 | Hooker | Centre of the front row; throws the ball at lineouts |
| 3 | Tighthead Prop | Right side of the scrum front row |
| 4 | Lock | Second row of the scrum; primary lineout jumper |
| 5 | Lock | Same as above |
| 6 | Blindside Flanker | Defence and ball-carrying on the narrow side |
| 7 | Openside Flanker | Specialist at winning turnovers at the breakdown |
| 8 | Number 8 | Back of the scrum; links forwards and backs |

### Backs (Jersey #9–15)

| # | Position | Role |
|---|----------|------|
| 9 | Scrum-half | Distributes the ball from rucks and scrums |
| 10 | Fly-half | Directs the attack; usually the team's kicker |
| 11 | Left Wing | Finisher on the left side; relies on speed |
| 12 | Inside Centre | Crash-ball carrier; breaks the defensive line |
| 13 | Outside Centre | Creates space and distributes to the wings |
| 14 | Right Wing | Finisher on the right side; relies on speed |
| 15 | Fullback | Last line of defence; fields high balls and counter-attacks |

---

## 4. Key Set Pieces

### Scrum
- All 8 forwards from each team bind together and push against each other to contest the ball
- The **Front Row** (positions 1, 2, 3) are specialist positions — they cannot be filled by players from other positions for safety reasons
- The App's **Lineout Checker** automatically validates that front-row positions are correctly assigned

### Lineout
- A method of restarting play after the ball goes into touch (out of bounds)
- One team throws the ball in while players from both teams line up and jump to compete for it
- The App tracks three Lineout roles:
  - **Thrower** — usually the Hooker (#2)
  - **Jumper** — usually the Locks (#4, #5)
  - **Lifter** — players who lift the jumper into the air

### Ruck
- Formed after a tackle; players from both teams bind over the ball on the ground to contest possession

---

## 5. Discipline

| Card | Effect |
|------|--------|
| **Yellow Card** | Player is temporarily sent off for **10 minutes** (Sin Bin); team plays with one fewer player |
| **Red Card** | Player is permanently sent off; no replacement allowed |

> The App's Match Engine includes a yellow card timer (10-minute countdown) and red card tracking, with cumulative card counts shown on each player's profile.

---

## 6. Substitutions

- A match squad typically includes **8 substitutes** (jersey #16–23)
- Front-row replacements (Prop / Hooker) are mandatory to ensure scrum safety
- The App's Match Engine supports real-time substitution management

---

## 7. How This App Maps to Rugby Concepts

| Rugby Concept | App Feature |
|--------------|-------------|
| 15 positions | Match Engine with 15 position slots for drag-and-drop lineup selection |
| Scoring types | Player stats tracking: Try / Conversion / Penalty / Drop Goal |
| Lineout roles | Player tags: Jumper / Lifter / Thrower |
| Yellow & Red cards | Real-time match recording; cumulative stats on player cards |
| Front-row specialists | Lineout Checker validates positions 1–3 compliance |
| Kicker | Player tag to mark the designated kicker (usually #10 or #15) |
| Captain / Vice-captain | Player tags: Cap / Vice |
| Match venues | Built-in database of Hong Kong sports grounds and rugby pitches |
