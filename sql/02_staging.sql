-- Cleaned, analysis-ready table: snake_case columns, country names joined in,
-- and a 0 rating ("Not rated") turned into NULL so it doesn't skew averages.
create or replace table restaurants as
select
    r."Restaurant ID"            as restaurant_id,
    trim(r."Restaurant Name")    as restaurant_name,
    r."Country Code"             as country_code,
    c.country,
    trim(r."City")               as city,
    r."Address"                  as address,
    r."Locality"                 as locality,
    r."Longitude"                as longitude,
    r."Latitude"                 as latitude,
    r."Cuisines"                 as cuisines,
    r."Average Cost for two"     as avg_cost_for_two,
    r."Currency"                 as currency,
    r."Has Table booking"        as has_table_booking,
    r."Has Online delivery"      as has_online_delivery,
    r."Is delivering now"        as is_delivering_now,
    r."Price range"              as price_range,
    nullif(r."Aggregate rating", 0) as rating,
    r."Rating text"              as rating_text,
    r."Votes"                    as votes
from raw_restaurants r
left join country_codes c on c.country_code = r."Country Code";

-- One row per restaurant per cuisine (Cuisines is a comma-separated list).
create or replace table restaurant_cuisines as
select restaurant_id, trim(cuisine) as cuisine
from restaurants, unnest(string_split(cuisines, ',')) as t(cuisine)
where cuisines is not null;
