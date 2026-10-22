-- Analysis tables ("marts") that answer the business questions in docs/analysis_plan.md.
-- Every mart is grouped by region so the dashboard can switch regions without re-querying.
-- A "high rating" is an aggregate rating of 4.0 or more (Zomato's "Very Good" and "Excellent").

-- Regions overlap on purpose: a New Delhi restaurant counts in "New Delhi", "Delhi NCR" and "All".
create or replace table restaurant_regions as
select restaurant_id, 'All' as region from restaurants
union all
select restaurant_id, 'Delhi NCR' from restaurants
where city in ('New Delhi', 'Gurgaon', 'Noida', 'Faridabad', 'Ghaziabad')
union all
select restaurant_id, city from restaurants
where city in ('New Delhi', 'Gurgaon', 'Noida', 'Faridabad')
union all
select restaurant_id, 'Other Indian cities' from restaurants
where country = 'India' and city not in ('New Delhi', 'Gurgaon', 'Noida', 'Faridabad', 'Ghaziabad')
union all
select restaurant_id, 'Outside India' from restaurants
where country <> 'India';

create or replace table region_list as
select region, count(*) as restaurants,
       case region when 'All' then 1 when 'Delhi NCR' then 2 when 'New Delhi' then 3 when 'Gurgaon' then 4
                   when 'Noida' then 5 when 'Faridabad' then 6 when 'Other Indian cities' then 7 else 8 end as sort_order
from restaurant_regions
group by region;

-- Q1. Which price tier gives a new restaurant the best chance of a high rating?
-- Includes a 95% Wilson interval on the high-rating share, so small samples show their uncertainty.
create or replace table mart_price_tier as
with base as (
    select rr.region, r.*
    from restaurant_regions rr join restaurants r using (restaurant_id)
),
agg as (
    select
        region,
        price_range,
        count(*)                                          as restaurants,
        count(rating)                                     as rated,
        avg(rating)                                       as avg_rating,
        count(*) filter (where rating >= 4.0)             as high_rated,
        median(votes)                                     as median_votes,
        -- Cost is in local currency, so only report it when the region has one currency.
        case when count(distinct currency) = 1 then median(avg_cost_for_two) end as median_cost_for_two,
        case when count(distinct currency) = 1 then any_value(currency) end      as currency
    from base
    group by region, price_range
)
select
    region,
    price_range,
    restaurants,
    rated,
    round(1 - rated / restaurants, 4)                                 as share_unrated,
    round(restaurants / sum(restaurants) over (partition by region), 4) as share_of_restaurants,
    round(avg_rating, 2)                                              as avg_rating,
    high_rated,
    round(high_rated / nullif(rated, 0), 4)                           as share_high_rated,
    -- Wilson score interval, z = 1.96
    round((high_rated / rated + 1.9208 / rated
           - 1.96 * sqrt((high_rated / rated) * (1 - high_rated / rated) / rated + 0.9604 / (rated * rated)))
          / (1 + 3.8416 / rated), 4)                                  as share_high_low,
    round((high_rated / rated + 1.9208 / rated
           + 1.96 * sqrt((high_rated / rated) * (1 - high_rated / rated) / rated + 0.9604 / (rated * rated)))
          / (1 + 3.8416 / rated), 4)                                  as share_high_high,
    median_votes,
    median_cost_for_two,
    currency
from agg
where rated > 0;

-- Q2. Which cuisine and price combinations rate best? (cells with fewer than 10 rated restaurants dropped)
create or replace table mart_cuisine_price as
with top_cuisines as (
    select rr.region, c.cuisine
    from restaurant_regions rr
    join restaurant_cuisines c using (restaurant_id)
    group by rr.region, c.cuisine
    qualify row_number() over (partition by rr.region order by count(*) desc, c.cuisine) <= 12
)
select
    rr.region,
    c.cuisine,
    r.price_range,
    count(r.rating)                                   as rated,
    round(avg(r.rating), 2)                           as avg_rating,
    round(avg((r.rating >= 4.0)::int), 4)             as share_high_rated
from restaurant_regions rr
join restaurants r using (restaurant_id)
join restaurant_cuisines c using (restaurant_id)
join top_cuisines t on t.region = rr.region and t.cuisine = c.cuisine
where r.rating is not null
group by all
having count(r.rating) >= 10;

-- Q3. Which localities are strongest, and how crowded are they? (localities with at least 20 restaurants)
create or replace table mart_locality as
select
    rr.region,
    r.city,
    r.locality,
    r.city || ' · ' || r.locality                     as locality_key,
    count(*)                                          as restaurants,
    count(r.rating)                                   as rated,
    round(avg(r.rating), 2)                           as avg_rating,
    round(avg((r.rating >= 4.0)::int) filter (where r.rating is not null), 4) as share_high_rated,
    round(avg(r.price_range), 2)                      as avg_price_range,
    round(avg((r.price_range >= 3)::int), 4)          as share_upscale
from restaurant_regions rr
join restaurants r using (restaurant_id)
where rr.region <> 'All'
group by all
having count(*) >= 20;

-- Q4. Does engagement (votes) go with rating? Grouped into vote bands.
create or replace table mart_votes as
select
    rr.region,
    case when votes < 10 then 1 when votes < 50 then 2 when votes < 200 then 3 when votes < 1000 then 4 else 5 end as band_order,
    case when votes < 10 then '0–9' when votes < 50 then '10–49' when votes < 200 then '50–199'
         when votes < 1000 then '200–999' else '1,000+' end as vote_band,
    count(*)                                          as rated,
    round(avg(rating), 2)                             as avg_rating,
    round(avg((rating >= 4.0)::int), 4)               as share_high_rated
from restaurant_regions rr
join restaurants r using (restaurant_id)
where r.rating is not null
group by all;

-- Q5. Do table booking and online delivery go with higher ratings at the same price tier?
create or replace table mart_services as
with base as (
    select rr.region, r.price_range, r.rating, 'Table booking' as service, r.has_table_booking as offered
    from restaurant_regions rr join restaurants r using (restaurant_id)
    union all
    select rr.region, r.price_range, r.rating, 'Online delivery', r.has_online_delivery
    from restaurant_regions rr join restaurants r using (restaurant_id)
)
select
    region,
    service,
    price_range,
    case when offered then 'Offered' else 'Not offered' end as offered,
    region || '|' || service || '|' || price_range || '|' || offered as row_key,
    count(rating)                                     as rated,
    round(avg(rating), 2)                             as avg_rating
from base
where rating is not null
group by all
having count(rating) >= 10;

-- Map: one point per restaurant, dropping coordinates more than ~0.5 degrees from the city's median
-- (the source has zeros and a few points placed in the wrong country).
create or replace table mart_map_points as
with city_center as (
    select city, country, median(latitude) as lat, median(longitude) as lon
    from restaurants where latitude <> 0 and longitude <> 0
    group by city, country
)
select
    r.restaurant_id,
    r.restaurant_name,
    r.city,
    r.locality,
    round(r.latitude, 5)  as latitude,
    round(r.longitude, 5) as longitude,
    r.rating,
    r.price_range,
    r.votes,
    -- Every region the restaurant belongs to, separated by "|", so the map can filter by region.
    (select string_agg(rr.region, '|' order by rr.region) from restaurant_regions rr
     where rr.restaurant_id = r.restaurant_id) as regions
from restaurants r
join city_center c using (city, country)
where abs(r.latitude - c.lat) <= 0.5 and abs(r.longitude - c.lon) <= 0.5;

-- Map at world scale: one bubble per city.
create or replace table mart_map_cities as
select
    r.country,
    p.city,
    round(median(p.latitude), 4)                      as latitude,
    round(median(p.longitude), 4)                     as longitude,
    count(*)                                          as restaurants,
    round(avg(p.rating), 2)                           as avg_rating
from mart_map_points p
join restaurants r using (restaurant_id)
group by all;
