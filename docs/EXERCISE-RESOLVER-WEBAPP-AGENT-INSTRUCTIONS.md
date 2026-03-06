# Exercise Resolver — Web App Implementation Guide
> For your VSCode AI agent. Paste this entire document as the prompt.

---

## Context

Kinex Fit iOS app parses workout captions from Instagram and TikTok. After local fuzzy matching
and a primary LLM enrichment call (`/api/ingest`), exercises that still can't be matched are
sent to a new endpoint: **`POST /api/mobile/exercise/resolve`**.

This endpoint receives a list of raw exercise name strings extracted from social media captions
and returns the canonical exercise name for each, resolved via LLM + a reference exercise list.

The tech stack is **Next.js (App Router)**, TypeScript, with existing patterns at
`app/api/mobile/` routes.

---

## Task 1 — Create the API route

**File:** `app/api/mobile/exercise/resolve/route.ts`

### Request body schema
```typescript
{
  exercises: string[];       // raw names from the caption, e.g. ["rdl", "bss", "nordic"]
  captionContext?: string;   // full caption text for additional LLM context (optional)
}
```

### Response schema
```typescript
{
  resolutions: Array<{
    rawName: string;
    canonicalName: string;
    confidence: number;      // 0.0 – 1.0
    kinexExerciseID?: string | null;
  }>;
}
```

### Implementation requirements

1. **Validate the request** — reject non-array `exercises`, empty arrays, or arrays with >50 items.

2. **Build the LLM prompt** using the pattern from other `/api/mobile/ai/` routes in the codebase.
   Use the existing `openai` or LLM client already wired into the project.

3. **System prompt** — use this exact prompt:

```
You are a fitness exercise name normalizer. Your job is to map informal, abbreviated, or
colloquial exercise names to their canonical fitness names.

Rules:
- Return ONLY the canonical name (e.g. "Romanian Deadlift" not "rdl")
- If the input is already a canonical name, return it unchanged
- If the input is genuinely ambiguous with no caption context, return null
- Confidence: 1.0 = certain, 0.85 = very likely, 0.70 = probable, 0.60 = possible, <0.60 = do not return

Common abbreviations to know:
RDL → Romanian Deadlift
OHP → Overhead Press
BSS → Bulgarian Split Squat
CGBP → Close Grip Bench Press
BTN → Behind the Neck Press
RFESS → Bulgarian Split Squat
GHR → Glute Ham Raise
TTB / T2B → Toes to Bar
HSPU → Handstand Push-Up
TGU → Turkish Get-Up
KB → Kettlebell (prefix, e.g. "KB Swing" → "Kettlebell Swing")
DB → Dumbbell (prefix)
BB → Barbell (prefix)
BPA → Band Pull-Apart
SLDL → Stiff Leg Deadlift
PC → Power Clean
HPC → Hang Power Clean
CJ / C&J → Clean and Jerk
SL → Single Leg (prefix)
Nordic / nh curl / nordic hamstring → Nordic Curl
Copenhagen / copen / cop plank → Copenhagen Adductor Plank
Pendlay row → Barbell Row
Meadows row → Dumbbell Row
Yates row → Barbell Row
Kroc row → Dumbbell Row
Seal row → Barbell Row
Skull crusher / JHC → Skull Crusher
French press (lying) → Skull Crusher
French press (seated/standing) → Overhead Triceps Extension
Z-press / floor OHP → Z-Press
Ski erg / skierg → Ski Erg
Echo bike / assault bike / air bike → Bike Erg
Prowler → Sled Push
```

4. **User prompt** — format it as:

```
Normalize these exercise names. For each, return the canonical name, confidence (0-1), and whether
you found a match.

Caption context (use this to resolve ambiguity):
"""
{captionContext or "none provided"}
"""

Exercise names to resolve:
{exercises.map((e, i) => `${i + 1}. "${e}"`).join('\n')}

Return a JSON array (no markdown, no extra text):
[
  { "rawName": "rdl", "canonicalName": "Romanian Deadlift", "confidence": 0.99 },
  { "rawName": "...", "canonicalName": "...", "confidence": 0.0 }
]

If you cannot resolve a name, still include it with canonicalName = null and confidence = 0.
```

5. **Parse the LLM JSON response** — use `JSON.parse()` with a try/catch. If parsing fails,
   return all names as unresolved (confidence 0).

6. **Match resolved names to Kinex exercise IDs** — after getting the canonical names from the
   LLM, do a database lookup for each `canonicalName`:
   ```
   SELECT id FROM exercises WHERE LOWER(name) = LOWER(canonicalName) LIMIT 1
   ```
   Attach the found `id` as `kinexExerciseID`. Null if not found.

7. **Filter out low-confidence results** — if `confidence < 0.60`, return with `canonicalName`
   set to the original `rawName` and `confidence: 0` (don't pollute with bad guesses).

8. **Auth** — this route requires a valid session token (same auth middleware as other
   `/api/mobile/` routes). Check how existing routes in `app/api/mobile/` handle auth and
   follow the same pattern.

9. **Rate limiting** — apply the same rate limiting used by other mobile AI endpoints.

10. **Error handling** — follow the same error response format as other `/api/mobile/` routes.
    On LLM error, return 200 with all resolutions having `confidence: 0` (don't fail the client).

---

## Task 2 — Improve the existing `/api/ingest` LLM prompt

**File:** wherever the ingest LLM prompt is defined (likely `app/api/ingest/route.ts` or
a shared lib file).

Find the existing prompt that parses workout captions. **Add** the following section to the
system prompt, just before the output format instructions:

```
EXERCISE NAME NORMALIZATION — always normalize exercise names to their canonical form:
- "rdl" → "Romanian Deadlift"
- "ohp" → "Overhead Press"
- "bss" / "bulgarians" → "Bulgarian Split Squat"
- "cgbp" → "Close Grip Bench Press"
- "nordic" / "nh curl" → "Nordic Curl"
- "copenhagen" / "copen plank" → "Copenhagen Adductor Plank"
- "kb swing" → "Kettlebell Swing"
- "t2b" / "ttb" → "Toes to Bar"
- "hspu" → "Handstand Push-Up"
- "tgu" → "Turkish Get-Up"
- "bpa" → "Band Pull-Apart"
- "pallof" → "Pallof Press"
- "meadows row" → "Dumbbell Row"
- "pendlay row" → "Barbell Row"
- "yates row" → "Barbell Row"
- "kroc row" → "Dumbbell Row"
- "ski erg" / "skierg" → "Ski Erg"
- "echo bike" / "assault bike" → "Bike Erg"
- "prowler" → "Sled Push"
- "amrap" / "emom" / "tabata" → these are WORKOUT FORMATS, not exercises; set as the workout type
```

---

## Task 3 — Optional: Periodically sync exercises from wger

**File:** `lib/exercise-sync.ts` (new)

This is optional but keeps your exercise database current with newly trending exercises without
manual maintenance.

```typescript
// Fetch exercises from wger public API (free, no auth required)
// Docs: https://wger.de/api/v2/exercise/?format=json&language=2&limit=100
// language=2 is English

export async function syncExercisesFromWger() {
  const BASE = 'https://wger.de/api/v2/exercise/';
  let url = `${BASE}?format=json&language=2&limit=100&offset=0`;

  while (url) {
    const res = await fetch(url);
    const data = await res.json();

    for (const exercise of data.results) {
      const name = exercise.name?.trim();
      if (!name) continue;

      // Upsert into your exercises table
      // Only add if no exercise with this name exists already
      await db.exercises.upsert({
        where: { name_lower: name.toLowerCase() },
        update: { wgerSynced: true },
        create: {
          name,
          source: 'wger',
          wgerSynced: true,
          // map wger category to your category system
        }
      });
    }

    url = data.next; // null when done
  }
}
```

Schedule this to run weekly via a cron job or Next.js scheduled route.

---

## Task 4 — Add `/api/mobile/exercise/resolve` to auth & rate-limit allowlists

Search your codebase for where `/api/mobile/` routes are registered for:
1. Auth middleware
2. Rate limiting middleware

Add `/api/mobile/exercise/resolve` to both, using the same settings as
`/api/mobile/ai/enhance-workout`.

---

## Summary of files to create/modify

| Action | File |
|--------|------|
| **CREATE** | `app/api/mobile/exercise/resolve/route.ts` |
| **MODIFY** | `app/api/ingest/route.ts` (or wherever ingest LLM prompt lives) |
| **CREATE** (optional) | `lib/exercise-sync.ts` |
| **MODIFY** | Auth middleware allowlist |
| **MODIFY** | Rate limit middleware allowlist |

---

## Testing

After implementing, test with this curl:

```bash
curl -X POST https://kinexfit.com/api/mobile/exercise/resolve \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "exercises": ["rdl", "bss", "nordic", "copenhagen plank", "kb swing", "ohp", "cgbp"],
    "captionContext": "Leg day! 4 rounds\n3x10 rdl\n3x8 bss each side\n4x6 nordic\n30s copenhagen plank"
  }'
```

Expected response:
```json
{
  "resolutions": [
    { "rawName": "rdl", "canonicalName": "Romanian Deadlift", "confidence": 0.99, "kinexExerciseID": "..." },
    { "rawName": "bss", "canonicalName": "Bulgarian Split Squat", "confidence": 0.99, "kinexExerciseID": "..." },
    { "rawName": "nordic", "canonicalName": "Nordic Curl", "confidence": 0.97, "kinexExerciseID": "..." },
    { "rawName": "copenhagen plank", "canonicalName": "Copenhagen Adductor Plank", "confidence": 0.97, "kinexExerciseID": null },
    { "rawName": "kb swing", "canonicalName": "Kettlebell Swing", "confidence": 0.99, "kinexExerciseID": "..." },
    { "rawName": "ohp", "canonicalName": "Overhead Press", "confidence": 0.99, "kinexExerciseID": "..." },
    { "rawName": "cgbp", "canonicalName": "Close Grip Bench Press", "confidence": 0.99, "kinexExerciseID": "..." }
  ]
}
```
