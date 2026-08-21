# Analytics (Firebase / GA4)

Events only show as a **count** until you register the parameters below. That is why custom events often look empty later.

Do this **once** in Firebase after the next TestFlight (or after you open the app in DebugView):

1. Open [Firebase Console](https://console.firebase.google.com/) → project **taptico-9bbe6**
2. **Analytics** → **Custom definitions** → **Create custom dimension**
3. Add these four. Names can match the table; the **Event / user property** column must match exactly.

| Dimension name | Scope | Event / user property |
| --- | --- | --- |
| Fidget | Event | `item_name` |
| Fidget id | Event | `item_id` |
| Fidget tier | Event | `fidget_tier` |
| User type | User | `user_type` |

4. **Analytics** → **Events** → open `purchase` → mark as **conversion** (optional, recommended)

Wait up to 24 hours for standard reports. Use **DebugView** for the same day.

## What we send

| Event | When | What you get |
| --- | --- | --- |
| `fidget_open` | User opens a fidget | Count per fidget (`item_name`), free vs premium (`fidget_tier`), paid vs free user (`user_type`) |
| `fidget_play` | Leave a fidget after 2+ seconds | Same labels plus `value` = seconds spent |
| `paywall_shown` | Locked fidget or Unlock tap | `item_name` of the fidget, or `header` |
| `paywall_buy_tap` | Buy button | Price string |
| `paywall_restore_tap` | Restore | — |
| `purchase` | Lifetime unlock succeeds | `$4.99 USD`; user is then `paid` |
| `reach_mode` | Settings reach change | `label` |

`user_type` is also a **user property** (`paid` / `free`) and a default parameter on every event. After you register it, you can filter any report: paid people vs free people.

## How to read it (simple)

**Which fidgets are popular**

Analytics → **Events** → `fidget_open` → breakdown by **Fidget** (`item_name`).

**Free toy vs paid toy**

Same report, breakdown by **Fidget tier** (`free` / `premium`).

**Do paying users still use the free ones?**

1. Analytics → **Events** → `fidget_open`
2. Add comparison / filter **User type** = `paid`
3. Breakdown by **Fidget**

Or: Analytics → **Explorations** → Free form → rows = Fidget, columns = User type, values = Event count.

**Did they pay?**

Events → `purchase`, or filter any report by User type = `paid`.

## Same-day testing

DebugView is the only real-time path. Standard Events reports lag.

On a device build, Firebase DebugView needs the Xcode launch argument `-FIRDebugEnabled` (Product → Scheme → Edit Scheme → Run → Arguments). CI TestFlight builds will not show in DebugView unless that flag is on; they still land in Events after the delay.
