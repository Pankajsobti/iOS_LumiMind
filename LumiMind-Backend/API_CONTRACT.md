# LumiMind API Contract

**Status: LOCKED.** This document is the single source of truth for every
`/api/v1` endpoint, request/response shape, and data model field name. No
future prompt (backend or iOS) may invent, rename, or restructure a field
or route without updating this file first.

- Base URL: `http://localhost:5000/api/v1`
- All request/response bodies are JSON.
- All authenticated routes require header: `Authorization: Bearer <JWT>`
- Dates are ISO-8601 strings on the wire (e.g. `"2026-08-08T14:30:00.000Z"`).

---

## Canonical category names (no drift, no exceptions)

There is exactly **one** locked list of six game categories. Every layer of
the app references it — nothing renames or reformats it independently.

| Canonical name (`GameCategory` rawValue / `GameResult.category` value / Mongoose enum) | `categoryScores` JSON key (camelCase) | DesignSystem gradient |
|---|---|---|
| `Speed` | `speed` | `speedGradient` |
| `Memory` | `memory` | `memoryGradient` |
| `Attention` | `attention` | `attentionGradient` |
| `Flexibility` | `flexibility` | `flexibilityGradient` |
| `Problem Solving` | `problemSolving` | `problemSolvingGradient` |
| `Math` | `math` | `mathGradient` |

The left column is used wherever a category is a **display/value string**
(`GameResult.category`). The right column is used wherever a category is
an **object key** (`User.categoryScores`). This mapping is defined once,
in `GameResult.swift` (`GameCategory.categoryScoresKey`) and mirrored in
`User.js`'s `categoryScoresSchema` — nowhere else.

## Canonical game names -> category

| `gameName` | `category` |
|---|---|
| `Memory Matrix` | `Memory` |
| `Speed Match` | `Speed` |
| `Lost in Migration` | `Attention` |
| `Brain Shift` | `Flexibility` |
| `Pirate Passage` | `Problem Solving` |
| `Splitting Seeds` | `Math` |

---

## Data Models

### User

```json
{
  "_id": "665f1a2b3c4d5e6f7a8b9c0d",
  "email": "user@example.com",
  "goals": ["Improve focus", "Boost memory"],
  "difficultyLevel": "Intermediate",
  "categoryScores": {
    "speed": 0,
    "memory": 0,
    "attention": 0,
    "flexibility": 0,
    "problemSolving": 0,
    "math": 0
  },
  "streak": 0,
  "lastPlayedDate": null,
  "createdAt": "2026-08-08T14:30:00.000Z",
  "updatedAt": "2026-08-08T14:30:00.000Z"
}
```

Notes:
- `passwordHash` exists on the backend document only. It is **never**
  present in any JSON response — excluded via `select: false` and a
  `toJSON` transform.
- `goals` and `difficultyLevel` are absent/`null` until
  `PATCH /users/onboarding` is called.
- `categoryScores` values are `Number` (backend) / `Double` (Swift),
  default `0` for every key.

### GameResult

```json
{
  "_id": "665f1a2b3c4d5e6f7a8b9c0e",
  "userId": "665f1a2b3c4d5e6f7a8b9c0d",
  "gameName": "Splitting Seeds",
  "category": "Math",
  "score": 1240,
  "durationSeconds": 62,
  "isFitTest": false,
  "playedAt": "2026-08-08T14:30:00.000Z"
}
```

`gameName` is one of the 6 locked game names. `category` is one of the 6
locked category names (see table above) and must always be the category
that `gameName` maps to.

---

## Endpoints

### `POST /auth/signup`
- **Auth:** none
- **Body:**
  ```json
  { "email": "user@example.com", "password": "hunter2" }
  ```
- **Response `201`:**
  ```json
  {
    "token": "eyJhbGciOiJIUzI1NiIs...",
    "user": { "...": "User object, see above" }
  }
  ```

### `POST /auth/login`
- **Auth:** none
- **Body:**
  ```json
  { "email": "user@example.com", "password": "hunter2" }
  ```
- **Response `200`:**
  ```json
  {
    "token": "eyJhbGciOiJIUzI1NiIs...",
    "user": { "...": "User object, see above" }
  }
  ```

### `PATCH /users/onboarding`
- **Auth:** required
- **Body:**
  ```json
  { "goals": ["Improve focus", "Boost memory"], "difficultyLevel": "Intermediate" }
  ```
- **Response `200`:** updated `User` object (see above)

### `GET /users/me`
- **Auth:** required
- **Response `200`:** `User` object (see above)

### `POST /game-results`
- **Auth:** required
- **Body:**
  ```json
  {
    "gameName": "Splitting Seeds",
    "category": "Math",
    "score": 1240,
    "durationSeconds": 62,
    "isFitTest": false
  }
  ```
- **Behavior:** creates a `GameResult`, then updates the authenticated
  user's `categoryScores` (for the result's category), `streak`, and
  `lastPlayedDate`.
- **Response `201`:**
  ```json
  {
    "gameResult": { "...": "GameResult object, see above" },
    "updatedUser": { "...": "User object, see above" }
  }
  ```

### `GET /game-results`
- **Auth:** required
- **Query params (optional):**
  - `category` — one of the 6 locked category names
  - `limit` — max number of results
- **Response `200`:** array of `GameResult`, sorted `playedAt` descending
  ```json
  [
    { "...": "GameResult object" },
    { "...": "GameResult object" }
  ]
  ```

### `GET /users/me/stats`
- **Auth:** required
- **Response `200`:**
  ```json
  {
    "categoryScores": {
      "speed": 0, "memory": 0, "attention": 0,
      "flexibility": 0, "problemSolving": 0, "math": 0
    },
    "streak": 0,
    "lastPlayedDate": null
  }
  ```

---

## Errors

All non-2xx responses use this shape:

```json
{ "error": "Human-readable message" }
```

Common status codes: `400` (validation), `401` (missing/invalid token),
`404` (not found), `409` (e.g. duplicate email on signup), `500` (server
error).

---

## Out of scope for this contract

Route handlers, controllers, JWT middleware implementation, password
hashing implementation, and validation logic are **not** defined here —
this document fixes shapes and paths only. Implementation is left to
future build prompts.