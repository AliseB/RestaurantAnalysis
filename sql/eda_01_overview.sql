-- Basic EDA starter queries. Run with:  duckdb zomato.duckdb < sql/eda_01_overview.sql

-- 1. Size and uniqueness
select count(*) as rows, count(distinct restaurant_id) as restaurants from restaurants;

-- 2. Missing / special values per column
select
    count(*) filter (where cuisines is null)          as missing_cuisines,
    count(*) filter (where rating is null)            as not_rated,
    count(*) filter (where avg_cost_for_two = 0)      as zero_cost,
    count(*) filter (where latitude = 0 or longitude = 0) as missing_coords
from restaurants;

-- 3. Summary statistics for every column
summarize restaurants;

-- 4. Restaurants by country
select country, count(*) as restaurants, round(avg(rating), 2) as avg_rating
from restaurants group by country order by restaurants desc;

-- 5. Top 10 cities by restaurant count
select country, city, count(*) as restaurants, round(avg(rating), 2) as avg_rating
from restaurants group by all order by restaurants desc limit 10;

-- 6. Rating distribution
select rating_text, count(*) as restaurants, min(rating) as min_rating, max(rating) as max_rating
from restaurants group by rating_text order by min_rating nulls first;

-- 7. Top 15 cuisines
select cuisine, count(*) as restaurants
from restaurant_cuisines group by cuisine order by restaurants desc limit 15;

-- 8. Price range vs rating and votes
select price_range, count(*) as restaurants,
       round(avg(rating), 2) as avg_rating, round(avg(votes)) as avg_votes
from restaurants group by price_range order by price_range;

-- 9. Do online delivery / table booking relate to rating?
select has_online_delivery, has_table_booking, count(*) as restaurants,
       round(avg(rating), 2) as avg_rating
from restaurants group by all order by all;
