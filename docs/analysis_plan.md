# Analysis plan: working backwards from business questions

The audience is someone opening a new restaurant. Each question below is something
they need to decide, then the metric that answers it, the SQL table that computes
it, and how it is shown.

**Definition used throughout:** a *high rating* is an aggregate rating of 4.0 or more
(Zomato's "Very Good" and "Excellent"). Restaurants with no rating yet (stored as 0)
are left out of rating metrics and counted separately as "not rated".

| # | Decision | Question | Metric | Table | View |
|---|---|---|---|---|---|
| 1 | Pricing | Which price tier gives the best chance of a high rating in my region? | Share of rated restaurants at 4.0+ by price tier, with a 95% Wilson interval | `mart_price_tier` | Bar chart with whiskers + detail table |
| 2 | Pricing | How crowded is each tier, and do cheap places get noticed? | Share of the region's restaurants per tier; share not yet rated | `mart_price_tier` | Bars + dots |
| 3 | Location | Where are the highly rated restaurants? | Rating per restaurant; per city at world scale | `mart_map_points`, `mart_map_cities` | Map |
| 4 | Location | Which neighbourhoods are strong, and how upscale are they already? | Average rating, share 4.0+, share in tiers 3–4, per locality | `mart_locality` | Sortable table |
| 5 | Concept | Which cuisine and price combinations rate best? | Share 4.0+ per cuisine × tier (≥10 rated) | `mart_cuisine_price` | Heatmap |
| 6 | Operations | Do table booking and online delivery go with better ratings at the same price? | Average rating with/without each service, per tier | `mart_services` | Dot plot |
| 7 | Marketing | How much do reviews matter? | Share 4.0+ by vote band | `mart_votes` | Bar chart |

Every table is grouped by **region** (All, Delhi NCR, New Delhi, Gurgaon, Noida,
Faridabad, Other Indian cities, Outside India), so the same question can be asked
for any market.

## First findings (Delhi NCR, 7,947 restaurants)

- **Price tier 3 (about Rs. 1,300 for two) is the most promising starting point.**
  23% of rated tier 3 restaurants reach 4.0+, against 3% in tier 1 and 6% in tier 2.
  Tier 4 (about Rs. 2,500) does about the same as tier 3 (24%) at almost twice the
  price, and its interval overlaps tier 3's.
- **Cheap places struggle to get noticed.** 40% of tier 1 restaurants have no rating at
  all, against 4% in tiers 3 and 4.
- **Tiers 3 and 4 are less crowded**: together they make up 14% of NCR restaurants.
- **Location matters**: Cyber Hub (Gurgaon), Khan Market and Connaught Place lead on
  rating, and they are mostly tier 3 markets.

## Caveats

- **One snapshot with no dates.** The data cannot show trends over time, or what happens
  to a restaurant after it opens. Every finding is an association among restaurants
  that exist today, not a cause.
- **Survivorship.** Closed restaurants aren't in the data, so the odds for every tier
  may look better than a new opening's real odds.
- **Outside India the sample is small and skews to top restaurants** (20–434 per country,
  under 2% unrated), so those figures overstate typical ratings.
- **Costs are in local currency.** The source labels Philippine prices "Botswana Pula".

## Rebuilding

```bash
python scripts/build_db.py               # raw -> staging -> marts in zomato.duckdb
python scripts/export_dashboard_data.py  # marts -> exports/*.csv for the dashboard
```

`exports/world_land_110m.json` holds Natural Earth 1:110m land outlines (public domain,
taken from the `world-atlas` npm package) for the map background. `dashboard/index.html`
is the source of the published dashboard page.
