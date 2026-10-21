-- Load the raw Kaggle CSV as-is (original column names kept).
create or replace table raw_restaurants as
select * from read_csv('data/raw/zomato.csv', header = true, auto_detect = true);

create or replace table country_codes as
select * from read_csv('data/seed/country_codes.csv', header = true, auto_detect = true);
