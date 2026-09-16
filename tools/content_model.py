"""Declutter Manor content plan: the item list, its slot costs, and the pacing model run over it.

Every set is every copy of one item type. It writes the generated half of docs/CONTENT.md:

    python3 tools/content_model.py            # the summary
    python3 tools/content_model.py --order    # every set in the order the model plays it
    python3 tools/content_model.py --md       # the generated tables, to paste into docs/CONTENT.md
    python3 tools/content_model.py --json > dev/content_plan.json   # what dev/ContentImport.tscn reads
"""
import json, random, sys
from collections import Counter, defaultdict

# --- Zones ----------------------------------------------------------------------------------
FLOORS = {
    "basement": ["rec_room", "laundry", "utility", "workshop", "storage"],
    "ground": ["entry_hall", "office", "living", "dining", "kitchen", "mudroom", "powder", "garage"],
    "upper": ["landing", "master_bed", "closet", "master_bath", "kids_room", "guest_room", "hall_bath"],
    "attic": ["attic"],
    "exterior": ["driveway", "deck", "pool_area", "side_garden"],
}
FLOOR_OF = {z: f for f, zs in FLOORS.items() for z in zs}
ZONES = [z for zs in FLOORS.values() for z in zs]

# --- Slot cost rule -------------------------------------------------------------------------
# cost = max(weight tier, bulk tier), rounded to the legal tiers 1/2/4/8.
#   weight: <= 0.5 kg -> 1, <= 2 kg -> 2, <= 8 kg -> 4, more -> 8
#   bulk:   held in the fingers or one closed hand -> 1
#           fills one hand, or two of it do not fit in one hand -> 2
#           needs both hands or an arm wrapped round it -> 4
#           needs both arms and blocks the view, or longer than you are wide -> 8
def cost(kg, bulk):
    w = 1 if kg <= 0.5 else 2 if kg <= 2 else 4 if kg <= 8 else 8
    return max(w, bulk)

# --- The list -------------------------------------------------------------------------------
# (id, name, count, kg each, bulk tier, home zone, home furniture, count note, tier)
# tier: 1 = scattered in the two starting rooms, 2 = one storey, 3 = the whole property.
ITEMS = [
    # Entry hall
    ("car_keys", "Car keys", 2, 0.1, 1, "entry_hall", "key hooks by the front door", "two adults, two cars", 1),
    ("umbrella", "Umbrella", 3, 0.5, 2, "entry_hall", "umbrella stand", "one each for the adults, one spare", 2),
    ("winter_coat", "Winter coat", 4, 1.5, 2, "entry_hall", "coat hooks", "one per person", 3),
    # Office
    ("laptop", "Laptop", 1, 1.8, 2, "office", "desk", "the family's shared work laptop", 2),
    ("binder", "Ring binder", 6, 0.8, 2, "office", "shelf above the desk", "taxes, insurance, house, school, medical, car", 3),
    # Living room
    ("tv", "Television", 1, 14.0, 8, "living", "TV stand", "one, as the author set", 3),
    ("tv_remote", "TV remote", 1, 0.15, 1, "living", "coffee table tray", "one", 1),
    ("game_controller", "Game controller", 2, 0.25, 1, "living", "TV stand shelf", "the console ships with one, the kids bought a second", 1),
    ("cushion", "Sofa cushion", 4, 0.5, 2, "living", "sofa", "3-5 on a three-seat sofa", 1),
    ("throw_blanket", "Throw blanket", 1, 1.2, 2, "living", "basket beside the sofa", "one", 2),
    ("book", "Book", 15, 0.5, 1, "living", "bookshelf", "the loose ones; the shelf keeps the rest", 3),
    ("picture_frame", "Picture frame", 4, 0.5, 1, "living", "mantel", "one row on a mantel", 2),
    # Dining room
    ("dinner_plate", "Dinner plate", 8, 0.6, 2, "dining", "sideboard", "the good plates, service for 8", 3),
    # Kitchen
    ("spoon", "Spoon", 12, 0.05, 1, "kitchen", "cutlery drawer", "service for 6, dinner and tea", 3),
    ("mug", "Mug", 8, 0.35, 1, "kitchen", "cupboard over the coffee maker", "two per person", 3),
    ("glass", "Drinking glass", 8, 0.3, 1, "kitchen", "glass cupboard", "two per person", 3),
    ("toaster", "Toaster", 1, 1.8, 2, "kitchen", "worktop", "one", 2),
    # Mudroom
    ("sneakers", "Sneakers", 8, 0.8, 2, "mudroom", "shoe rack", "two pairs per person", 3),
    ("backpack", "School backpack", 2, 1.5, 2, "mudroom", "bench hooks", "one per child", 2),
    ("dog_leash", "Dog leash", 1, 0.3, 1, "mudroom", "hook by the garage door", "one dog", 2),
    ("dog_toy", "Dog toy", 3, 0.2, 1, "mudroom", "dog basket", "", 2),
    # Half bath
    ("hand_towel", "Hand towel", 2, 0.2, 1, "powder", "towel ring", "one out, one spare", 2),
    # Garage
    ("bicycle", "Kids' bicycle", 2, 11.0, 8, "garage", "bike rack", "one per child; the adults' hang on the wall", 3),
    ("bike_helmet", "Bike helmet", 4, 0.35, 2, "garage", "helmet shelf", "one per person", 3),
    ("soda_can", "Empty soda can", 10, 0.015, 1, "garage", "recycling bin", "a week of cans", 3),
    # Laundry
    ("laundry_basket", "Laundry basket", 2, 1.0, 8, "laundry", "beside the dryer", "one for whites, one for colours", 3),
    # Utility
    ("paint_can", "Paint can", 4, 5.0, 4, "utility", "paint shelf", "leftover gallons from four rooms", 3),
    ("light_bulb", "Light bulb box", 4, 0.1, 1, "utility", "spares shelf", "", 3),
    # Workshop
    ("screwdriver", "Screwdriver", 6, 0.15, 1, "workshop", "pegboard rack", "a six-piece set", 3),
    ("wrench", "Wrench", 4, 0.3, 1, "workshop", "pegboard", "", 3),
    # Storage
    ("suitcase", "Suitcase", 2, 4.0, 8, "storage", "luggage shelf", "one checked, one carry-on", 3),
    ("decoration_box", "Holiday decoration box", 3, 3.0, 8, "storage", "storage shelves", "Christmas, Halloween, Easter", 3),
    ("sleeping_bag", "Sleeping bag", 4, 1.5, 4, "storage", "camping shelf", "one per person", 3),
    # Rec room
    ("board_game", "Board game", 6, 1.0, 2, "rec_room", "game shelf", "", 3),
    # Upstairs hall
    ("bath_towel", "Bath towel", 8, 0.7, 2, "landing", "linen cupboard", "two per person", 3),
    # Master bedroom
    ("pillow", "Bed pillow", 4, 0.9, 2, "master_bed", "bed", "two per sleeper on a queen bed", 3),
    ("phone_charger", "Phone charger", 2, 0.1, 1, "master_bed", "nightstands", "one per side", 3),
    # Walk-in closet
    ("hanger", "Clothes hanger", 15, 0.05, 1, "closet", "clothes rail", "the loose ones", 3),
    ("dress_shoes", "Dress shoes", 4, 0.9, 2, "closet", "shoe shelf", "two pairs per adult", 3),
    # Master bath
    ("perfume", "Perfume bottle", 3, 0.3, 1, "master_bath", "vanity", "", 3),
    # Kids' room
    ("toy_car", "Toy car", 12, 0.05, 1, "kids_room", "toy box", "", 3),
    ("plush_toy", "Stuffed animal", 8, 0.3, 2, "kids_room", "bed", "", 3),
    ("school_book", "School book", 5, 0.9, 2, "kids_room", "desk shelf", "", 3),
    # Guest room
    ("dumbbell", "Dumbbell", 2, 5.0, 2, "guest_room", "weight rack", "a pair", 3),
    # Hall bath
    ("rubber_duck", "Rubber duck", 6, 0.05, 1, "hall_bath", "tub edge", "", 3),
    ("toilet_roll", "Toilet paper roll", 6, 0.12, 2, "hall_bath", "cabinet under the basin", "a six-pack", 3),
    ("shampoo", "Shampoo bottle", 3, 0.5, 1, "hall_bath", "shower shelf", "", 3),
    # Attic
    ("photo_album", "Photo album", 4, 1.5, 2, "attic", "trunk", "", 3),
    # Front yard and driveway
    ("garden_gnome", "Garden gnome", 3, 3.0, 4, "driveway", "front flower bed", "", 3),
    # Deck
    ("grill_tool", "Grill tool", 3, 0.3, 2, "deck", "grill side hooks", "tongs, spatula, brush", 3),
    ("deck_cushion", "Deck chair cushion", 4, 0.8, 4, "deck", "deck chairs", "one per chair", 3),
    # Pool
    ("pool_noodle", "Pool noodle", 4, 0.2, 4, "pool_area", "pool bin", "one per person", 3),
    ("goggles", "Swim goggles", 4, 0.05, 1, "pool_area", "pool bin", "one per person", 3),
    # Side garden
    ("garden_hose", "Garden hose", 1, 4.5, 8, "side_garden", "hose reel", "one", 3),
    ("watering_can", "Watering can", 1, 1.0, 4, "side_garden", "potting bench", "one", 3),
]

# --- Pacing model (docs/PACING.md) ----------------------------------------------------------
SEARCH_S = 30.0
INTERACT_S = 5.0
SPEED = 2.8
LEG_M = {1: 10.0, 2: 16.0, 3: 24.0}  # one-way leg by scatter tier
GATHER_M = {1: 5.0, 2: 8.0, 3: 12.0}
MAX_SET_MIN = 12.0
FINALE_S = 60.0

def set_seconds(n, c, cap, tier):
    k = max(1, min(n, cap // c))
    per_item_m = 2 * LEG_M[tier] / k + GATHER_M[tier]
    return n * (SEARCH_S + INTERACT_S + per_item_m / SPEED), k

def play_order(items):
    """The order the model plays sets in: the lowest tier first, then whatever can be carried,
    smallest total slot weight first. It is a greedy player, not a scripted one."""
    todo = list(items)
    cap, order = 1, []
    while todo:
        carryable = [i for i in todo if i[4 if False else 0] and cost(i[3], i[4]) <= cap]
        tier_min = min(i[8] for i in (carryable or todo))
        pool = [i for i in (carryable or todo) if i[8] == tier_min]
        pick = min(pool, key=lambda i: (cost(i[3], i[4]) * i[2], i[0]))
        todo.remove(pick)
        order.append((pick, cap))
        cap += 1
    return order

def run():
    total = sum(i[2] for i in ITEMS)
    rows, t, over = [], 0.0, []
    for it, cap in play_order(ITEMS):
        c = cost(it[3], it[4])
        s, k = set_seconds(it[2], c, cap, it[8])
        if c > cap:
            over.append(it[0])
        t += s
        rows.append((it, cap, c, k, s, t))
        if s / 60 > MAX_SET_MIN:
            over.append(f"{it[0]} {s/60:.1f} min")
    t += FINALE_S
    return total, rows, t, over

# --- Scatter ---------------------------------------------------------------------------------
# About one start in ten is placed on purpose somewhere absurd. The rest are drawn once, from a
# fixed seed, and then frozen into the resources: every player gets the same house.
ABSURD = {
    "garden_hose": ("hall_bath", "coiled in the bathtub"),
    "toaster": ("attic", "on the trunk"),
    "rubber_duck": ("kitchen", "in the fridge door"),
    "book": ("kitchen", "in the freezer"),
    "goggles": ("kitchen", "in the fruit bowl"),
    "winter_coat": ("pool_area", "on a sun lounger"),
    "mug": ("side_garden", "in a flower pot"),
    "dinner_plate": ("driveway", "on the lawn, like a frisbee"),
    "pillow": ("garage", "on the car roof"),
    "bath_towel": ("deck", "over the grill lid"),
    "sneakers": ("kitchen", "in the oven"),
    "laundry_basket": ("pool_area", "at the shallow end steps"),
    "garden_gnome": ("master_bed", "tucked in on the pillow"),
    "bicycle": ("rec_room", "against the sofa"),
    "soda_can": ("closet", "on the shoe shelf"),
    "toilet_roll": ("deck", "inside the grill"),
    "dumbbell": ("dining", "in the fruit bowl"),
    "plush_toy": ("workshop", "clamped in the vise"),
    "decoration_box": ("pool_area", "on the diving board end"),
    "suitcase": ("driveway", "at the kerb"),
    "hanger": ("side_garden", "hung on the hose reel"),
    "school_book": ("hall_bath", "on the toilet tank"),
    "screwdriver": ("dining", "in the sideboard with the good plates"),
    "deck_cushion": ("laundry", "in the washer"),
    "photo_album": ("garage", "in the recycling bin"),
}
TIER_ZONES = {1: ["entry_hall", "living"], 2: FLOORS["ground"], 3: ZONES}
PER_ZONE = 250 / 25

def scatter(seed=20260914):
    rng = random.Random(seed)
    load = Counter()
    starts = defaultdict(Counter)
    for it in ITEMS:
        if it[0] in ABSURD:
            starts[it[0]][ABSURD[it[0]][0]] += 1
            load[ABSURD[it[0]][0]] += 1
    # Most constrained first, so the starting rooms are not filled by the whole-property sets.
    for it in sorted(ITEMS, key=lambda i: i[8]):
        n = it[2] - (1 if it[0] in ABSURD else 0)
        for _ in range(n):
            zones = [z for z in TIER_ZONES[it[8]] if z != it[5] or it[8] == 1]
            if cost(it[3], it[4]) == 8:
                zones = [z for z in zones if z != "attic"]
            lightest = min(load[z] - (PER_ZONE if it[8] < 3 else 0) for z in zones)
            pick = rng.choice([z for z in zones
                    if load[z] - (PER_ZONE if it[8] < 3 else 0) <= lightest + 2])
            starts[it[0]][pick] += 1
            load[pick] += 1
    return starts, load

if __name__ == "__main__" and "--md" not in sys.argv and "--json" not in sys.argv:
    total, rows, t, over = run()
    costs = [cost(i[3], i[4]) for i in ITEMS for _ in range(i[2])]
    print(f"types/sets {len(ITEMS)}  items {total}  mean cost {sum(costs)/len(costs):.2f}  "
          f"cost mix {sorted(Counter(costs).items())}")
    homes = Counter()
    for i in ITEMS:
        homes[i[5]] += i[2]
    print("home items per zone:", dict(homes))
    print("zones with no home:", [z for z in ZONES if z not in homes])
    print(f"model total {t/60:.0f} min, finale cost {1 + len(ITEMS)} slots, violations {over}")
    worst = max(rows, key=lambda r: r[4])
    print(f"longest set {worst[0][0]} {worst[4]/60:.1f} min")
    if "--order" in sys.argv:
        for it, cap, c, k, s, tt in rows:
            print(f"{it[0]:16} n{it[2]:3} c{c} cap{cap:3} k{k:3} {s/60:5.1f} min  t={tt/60:5.0f}")

ZONE_NAME = {
    "rec_room": "Rec room", "laundry": "Laundry", "utility": "Utility", "workshop": "Workshop",
    "storage": "Storage", "entry_hall": "Entry hall", "office": "Home office", "living": "Living room",
    "dining": "Dining room", "kitchen": "Kitchen", "mudroom": "Mudroom", "powder": "Half bath",
    "garage": "Garage", "landing": "Upstairs hall", "master_bed": "Master bedroom",
    "closet": "Walk-in closet", "master_bath": "Master bath", "kids_room": "Kids' room",
    "guest_room": "Guest room", "hall_bath": "Hall bath", "attic": "Attic",
    "driveway": "Front yard and driveway", "deck": "Rear deck", "pool_area": "Pool area",
    "side_garden": "Side garden",
}
FLOOR_NAME = {"basement": "Basement", "ground": "Ground floor", "upper": "Upper floor",
              "attic": "Attic", "exterior": "Exterior"}

def markdown():
    total, rows, t, over = run()
    starts, load = scatter()
    costs = [cost(i[3], i[4]) for i in ITEMS for _ in range(i[2])]
    mix = Counter(costs)
    out = []
    w = out.append
    w("<!-- Everything below, down to \"What changes elsewhere\", is generated by tools/content_model.py. Change the list there and regenerate; do not edit the tables by hand. -->")
    w("")
    w("## The list, by where each item belongs")
    w("")
    w("\"Starts in\" is how many copies start in each zone. A zone marked * holds that item's")
    w("deliberately absurd spot, listed further down.")
    for floor, zones in FLOORS.items():
        w("")
        w(f"### {FLOOR_NAME[floor]}")
        for z in zones:
            its = [i for i in ITEMS if i[5] == z]
            if not its:
                continue
            w("")
            w(f"**{ZONE_NAME[z]}**")
            w("")
            w("| Item | Count | Slots each | Home | Why this many | Starts in |")
            w("|---|---|---|---|---|---|")
            for i in its:
                sp = starts[i[0]]
                absurd = ABSURD.get(i[0], ("", ""))[0]
                cells = ", ".join(f"{ZONE_NAME[k]}{'*' if k == absurd else ''} {v}"
                        for k, v in sorted(sp.items(), key=lambda kv: -kv[1]))
                w(f"| {i[1]} | {i[2]} | {cost(i[3], i[4])} | {i[6]} | {i[7] or '-'} | {cells} |")
    w("")
    w("## The absurd spots")
    w("")
    w(f"{len(ABSURD)} of {total} starts ({len(ABSURD) * 100 // total}%). One copy of each item below starts here.")
    w("")
    w("| Item | Zone | Where |")
    w("|---|---|---|")
    for k, (z, where) in ABSURD.items():
        name = next(i[1] for i in ITEMS if i[0] == k)
        w(f"| {name} | {ZONE_NAME[z]} | {where} |")
    w("")
    w("## Misplaced items per zone at the start")
    w("")
    w("| Zone | Starts | Homes |")
    w("|---|---|---|")
    homes = Counter()
    for i in ITEMS:
        homes[i[5]] += i[2]
    for z in ZONES:
        w(f"| {ZONE_NAME[z]} | {load[z]} | {homes[z]} |")
    w("")
    w("## Pacing, run over this list")
    w("")
    w(f"- Sets: **{len(ITEMS)}**. Items: **{total}**. Finale cost: **{1 + len(ITEMS)} slots** (1 to start + 1 per set).")
    w(f"- Slot costs: {mix[1]} items at 1, {mix[2]} at 2, {mix[4]} at 4, {mix[8]} at 8; mean **{sum(costs)/len(costs):.2f}**.")
    w(f"- Modelled run: **{t/60:.0f} min** against the 180-minute target.")
    worst = max(rows, key=lambda r: r[4])
    w(f"- Longest set: **{worst[0][1]}, {worst[4]/60:.1f} min** at {worst[1]} slots. Limit 12 min. Over the limit: {len([o for o in over if ' min' in o])}.")
    big = max(i[2] * cost(i[3], i[4]) for i in ITEMS)
    fits = next(r for r in rows if r[1] >= big)
    w(f"- From set {rows.index(fits) + 1} (~{fits[5]/60 - fits[4]/60:.0f} min in), capacity is {fits[1]}: every set fits in one trip.")
    w("")
    w("First ten sets in the model's order:")
    w("")
    w("| # | Set | Members | Slots each | Capacity | Minutes | Cumulative |")
    w("|---|---|---|---|---|---|---|")
    for n, (it, cap, c, k, s, tt) in enumerate(rows[:10], 1):
        w(f"| {n} | {it[1]} | {it[2]} | {c} | {cap} | {s/60:.1f} | {tt/60:.0f} |")
    return "\n".join(out)

if __name__ == "__main__" and "--md" in sys.argv:
    print(markdown())

def plan_json():
    """Every set in list order, with the zone each copy starts in. Copy n of a set always gets the
    same zone for the same list and seed: the absurd copy first, then the zones by name."""
    starts, _ = scatter()
    out = []
    for it in ITEMS:
        absurd = ABSURD.get(it[0], ("", ""))
        zones = []
        counts = Counter(starts[it[0]])
        if absurd[0]:
            zones.append(absurd[0])
            counts[absurd[0]] -= 1
        for zone in sorted(counts):
            zones.extend([zone] * counts[zone])
        out.append({
            "id": it[0], "name": it[1], "count": it[2], "slot_cost": cost(it[3], it[4]),
            "home_zone": it[5], "home": it[6], "tier": it[8], "starts": zones,
            "absurd": absurd[1],
        })
    return {"_comment": "Generated by tools/content_model.py --json. Do not edit.", "sets": out}

if __name__ == "__main__" and "--json" in sys.argv:
    print(json.dumps(plan_json(), indent=1))
