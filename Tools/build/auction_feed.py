"""Build the Auction Prices feed: every Forever auction house's lowest price per item, how many auctions
list it and its median price, from Blizzard's auction data, into NaowhForever_AuctionData/Prices.lua (ns.AuctionFeed).

Needs a Blizzard API client in BLIZZARD_CLIENT_ID and BLIZZARD_CLIENT_SECRET. The release
workflow runs it before packaging, so every release carries the prices of that hour. The feed's
time is Blizzard's Last-Modified of its oldest house with prices, not when this ran. A region with
no prices at all writes nothing and fails, so the workflow keeps the last prices it had.

Usage: python Tools/build/auction_feed.py [--summary] [--region us] [--out path]
"""
import argparse
import base64
import email.utils
import gzip
import http.client
import json
import os
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402

OUT = paths.ROOT / "NaowhForever_AuctionData" / "Prices.lua"
TOKEN_URL = "https://oauth.battle.net/token"
API = "https://{region}.api.blizzard.com/data/wow/ruleset/{ruleset}/auctions/{path}"
# Every ruleset lists the same houses, so one is enough (Normal, which every region has).
RULESET = 2
# GetCurrentRegion() in game.
REGIONS = {"us": 1, "eu": 3}
TIMEOUT = 120
TRIES, RETRY_WAIT = 3, 10
DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz"


def fetch(request):
    """The body and headers, tried again after a dropped connection, a timeout, a 429 or a 5xx."""
    for attempt in range(1, TRIES + 1):
        try:
            with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
                return response.read(), response.headers
        except (OSError, http.client.HTTPException) as error:
            code = getattr(error, "code", None)
            if attempt == TRIES or code is not None and code < 500 and code != 429:
                raise
            print(f"{request.full_url}: {error}, trying again", file=sys.stderr)
            time.sleep(RETRY_WAIT * attempt)


def token(client_id, secret):
    auth = base64.b64encode(f"{client_id}:{secret}".encode()).decode()
    request = urllib.request.Request(TOKEN_URL, data=b"grant_type=client_credentials",
                                     headers={"Authorization": f"Basic {auth}"})
    body, _ = fetch(request)
    return json.loads(body)["access_token"]


def get(access, region, path):
    query = urllib.parse.urlencode({"namespace": f"dynamic-forever-{region}", "locale": "en_US"})
    url = API.format(region=region, ruleset=RULESET, path=path) + "?" + query
    request = urllib.request.Request(url, headers={"Authorization": f"Bearer {access}",
                                                   "Accept-Encoding": "gzip"})
    body, headers = fetch(request)
    if headers.get("Content-Encoding") == "gzip":
        body = gzip.decompress(body)
    return json.loads(body), len(body), headers.get("Last-Modified")


def seconds(last_modified):
    return int(email.utils.parsedate_to_datetime(last_modified).timestamp())


def lowest(listings, prices, listed=None, amounts=None):
    """Fold listings into item ID -> lowest price for one, in copper, into listed, item ID -> how many
    auctions have a price, and into amounts, item ID -> {price for one: quantity}; bid-only auctions skipped."""
    for listing in listings or []:
        item, quantity = listing["item"]["id"], listing.get("quantity") or 1
        each = listing.get("unit_price")
        if each is None and listing.get("buyout"):
            each = listing["buyout"] // quantity
        if not each:
            continue
        if item not in prices or each < prices[item]:
            prices[item] = each
        if listed is not None:
            listed[item] = listed.get(item, 0) + 1
        if amounts is not None:
            counts = amounts.setdefault(item, {})
            counts[each] = counts.get(each, 0) + quantity
    return prices


def medians(amounts):
    """Item ID -> the price of the middle one of everything listed, weighted by quantity (the lower of two)."""
    out = {}
    for item, counts in amounts.items():
        total, seen = sum(counts.values()), 0
        for price in sorted(counts):
            seen += counts[price]
            if seen * 2 >= total:
                out[item] = price
                break
    return out


def base36(number):
    text = ""
    while True:
        number, digit = divmod(number, 36)
        text = DIGITS[digit] + text
        if not number:
            return text


def encode(prices, listed=None, middle=None):
    """"id:price:listed:median,..." in base 36, each ID as the step from the one before; ":listed" only for an
    item listed holds, and ":median" only for one middle holds (after an empty listed where there is none)."""
    parts, last = [], 0
    for item in sorted(prices):
        part = base36(item - last) + ":" + base36(prices[item])
        if listed and item in listed or middle and item in middle:
            part += ":" + (base36(listed[item]) if listed and item in listed else "")
        if middle and item in middle:
            part += ":" + base36(middle[item])
        parts.append(part)
        last = item
    return ",".join(parts)


def middles(found):
    """Per faction, each item's middle price across that faction's houses (the lower of two middles), the
    most auctions any house listing it at that price had, and the middle of the houses' medians, so the game
    never decodes every house for it."""
    out = {}
    for faction in sorted({house["faction"] for house in found.values() if house["prices"]}):
        mine = [house for house in found.values() if house["faction"] == faction and house["prices"]]
        each, middle = {}, {}
        for house in mine:
            for item, price in house["prices"].items():
                each.setdefault(item, []).append(price)
            for item, price in (house.get("medians") or {}).items():
                middle.setdefault(item, []).append(price)
        prices = {item: sorted(found_prices)[(len(found_prices) + 1) // 2 - 1] for item, found_prices in each.items()}
        middle = {item: sorted(values)[(len(values) + 1) // 2 - 1] for item, values in middle.items()}
        listed = {}
        for house in mine:
            for item, count in (house.get("listed") or {}).items():
                if house["prices"].get(item) == prices[item] and count > listed.get(item, 0):
                    listed[item] = count
        out[faction] = encode(prices, listed, middle)
    return out


def houses(access, region, summary=False):
    index, _, _ = get(access, region, "")
    if summary:
        print(json.dumps(index, indent=1)[:4000])
    found = {}
    for house in index.get("auctions", []):
        house_id, name = house["id"], house.get("name", "")
        started = time.time()
        listed, size, modified = get(access, region, str(house_id))
        goods, goods_size, goods_modified = get(access, region, f"{house_id}/commodities")
        counts, amounts = {}, {}
        prices = lowest(goods.get("auctions"), lowest(listed.get("auctions"), {}, counts, amounts), counts, amounts)
        found[house_id] = {"faction": name.split()[0] if name else "", "prices": prices, "listed": counts,
                           "medians": medians(amounts), "time": min(seconds(modified), seconds(goods_modified))}
        if summary:
            auctions, commodities = listed.get("auctions") or [], goods.get("auctions") or []
            print(f"{region} {house_id} {name!r}: {len(auctions)} auctions, {len(commodities)} commodities, "
                  f"{len(prices)} items, {(size + goods_size) // 1024} KB, {time.time() - started:.1f} s, "
                  f"Last-Modified {modified}")
            if auctions:
                print("  auction keys", sorted(auctions[0]), "item keys", sorted(auctions[0]["item"]))
            if commodities:
                print("  commodity keys", sorted(commodities[0]))
    return found


def lua(feed, at):
    lines = ["-- Prices.lua: every Forever auction house's lowest and median prices, built by Tools/build/auction_feed.py.",
             "local ns = _G.NaowhForever", "", "ns.AuctionFeed = {", f"    time = {at},", "    regions = {"]
    for region, found in feed.items():
        lines.append(f"        [{REGIONS[region]}] = {{")
        for house_id in sorted(found):
            house = found[house_id]
            prices = encode(house["prices"], house.get("listed"), house.get("medians"))
            lines.append(f'            [{house_id}] = {{ faction = "{house["faction"]}", prices = "{prices}" }},')
        lines.append("        },")
    lines += ["    },", "    middles = {"]
    for region, found in feed.items():
        lines.append(f"        [{REGIONS[region]}] = {{")
        for faction, prices in middles(found).items():
            lines.append(f'            {faction} = "{prices}",')
        lines.append("        },")
    lines += ["    },", "}", ""]
    return "\r\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--summary", action="store_true", help="print what Blizzard sends, write nothing")
    parser.add_argument("--region", choices=sorted(REGIONS), action="append")
    parser.add_argument("--out", type=Path, default=OUT)
    args = parser.parse_args()
    access = token(os.environ["BLIZZARD_CLIENT_ID"], os.environ["BLIZZARD_CLIENT_SECRET"])
    feed = {region: houses(access, region, args.summary) for region in args.region or sorted(REGIONS)}
    if args.summary:
        return
    empty = [region for region, found in feed.items() if not any(house["prices"] for house in found.values())]
    if empty:
        sys.exit(f"Blizzard sent no auction prices for {', '.join(empty)}: nothing written")
    at = min(house["time"] for found in feed.values() for house in found.values() if house["prices"])
    args.out.write_bytes(lua(feed, at).encode("ascii"))
    counts = ", ".join(f"{region} {len(found)} houses" for region, found in feed.items())
    print(f"wrote {args.out.name}: {counts}, {args.out.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
