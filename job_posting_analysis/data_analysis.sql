SELECT
	*
FROM
	jobs;

-- deleting rows 
DELETE FROM jobs
WHERE
	idx NOT IN (
		SELECT
			idx
		FROM
			jobs
		WHERE
			idx ~ E'^\\d+$'
	);

-- 1. How many records does this table contain?
DROP TABLE IF EXISTS get_record_count;

CREATE TEMP TABLE get_record_count AS (
	SELECT
		count(*) AS record_count
	FROM
		jobs
);

SELECT
	*
FROM
	get_record_count;

/*
record_count
--------------
45469
(1 row)
*/
-- 2. How many unique records does this table contain?
WITH
	get_unique_postings AS (
		SELECT
			count(DISTINCT description) AS record_count
		FROM
			jobs
		GROUP BY
			description
	)
SELECT
	sum(record_count) AS total_unique_records
FROM
	get_unique_postings;

/*
total_unique_records
----------------------
32079
(1 row)

*/
-- 3. List the days where there were no jobs posted.
WITH
	get_single_day AS (
		SELECT
			date::date AS post_date
		FROM
			jobs
		GROUP BY
			post_date
		ORDER BY
			post_date
	)
SELECT
	post_date
FROM
	get_single_day
WHERE
	NOT EXISTS (
		SELECT
			generate_series('2022-11-04', '2024-03-22', interval '1 day')::date
	);

/*

post_date
----------


*/
-- 4. List the top 20 companies and the number of exact job postings.
SELECT
	company_name,
	count(*) AS same_post_count
FROM
	jobs
GROUP BY
	company_name,
	description
HAVING
	count(*) > 1
ORDER BY
	same_post_count DESC
LIMIT
	20;

/*
company_name           | same_post_count
----------------------------------+-----------------
Cox Communications               |             258
Cox Communications               |              93
EDWARD JONES                     |              82
|              74
ATC                              |              73
Oklahoma Complete Health         |              72
EDWARD JONES                     |              67
AbbVie                           |              53
EDWARD JONES                     |              52
Saint Louis County Clerks Office |              50
Walmart                          |              44
EDWARD JONES                     |              38
Walmart                          |              35
EDWARD JONES                     |              35
Commercial Solutions             |              34
Walmart                          |              34
EDWARD JONES                     |              33
Tulsa Remote                     |              32
Walmart                          |              32
FlexJobs                         |              32
(20 rows)
*/
-- 5. List the first six fields (columns) and description tokens for five random rows from this table.
SELECT
	data_job_id,
	idx,
	title,
	company_name,
	job_location,
	via,
	description_tokens
FROM
	jobs
ORDER BY
	random()
LIMIT
	5;

/*
data_job_id | idx  |                      title                       |             company_name             |    job_location    |          via          |                         description_tokens

-------------+------+--------------------------------------------------+--------------------------------------+--------------------+-----------------------+---------------------------------------------------------------------
44846 | 513  | Senior Data Analyst, Business Optimization       | Cox Communications                   | Warr Acres, OK     | via ZipRecruiter      | ['tableau', 'microstrategy', 'excel', 'powerpoint', 'sql', 'swift']
45457 | 1124 | Salesforce Data Analyst                          | Aquent Talent                        | United States      | via My ArkLaMiss Jobs | ['excel', 'sql']
8947 | 252  | Senior Data Analyst, Engineering                 | Eversource Energy                    |   United States    | via BeBee             | ['ssis', 'mysql', 'sql', 'ssrs']
21580 | 2613 | Data Collection / Data Analyst / Data Extraction | Upwork                               |  Anywhere          | via Upwork            | []
3739 | 1777 | Health Information Data Analyst                  | Blue Cross and Blue Shield of Kansas |   Topeka, KS       | via ProActuary        | ['tableau', 'python', 'spss', 'excel', 'r', 'spreadsheet', 'sql']
(5 rows)
*/
-- 6. How many records do not have any salary information and what is the percentage of records that do not have any salary information?
WITH
	get_totals_cte AS (
		SELECT
			(
				SELECT
					*
				FROM
					get_record_count
			) AS total_records,
			count(*) AS no_salary_count
		FROM
			jobs
		WHERE
			salary_standardized IS NULL
	)
SELECT
	total_records AS total_record_count,
	no_salary_count,
	total_records - no_salary_count AS record_diff,
	round(100 * no_salary_count::numeric / total_records, 2) AS no_salary_percentage
FROM
	get_totals_cte;

/*
total_record_count | no_salary_count | record_diff | no_salary_percentage
--------------------+-----------------+-------------+----------------------
45469 |           37660 |        7809 |                82.83
(1 row) 

*/
-- 7. List basic salary statistics (mean, min, median...) for hourly rates and the specific shedule type.
WITH
	get_hourly_stats AS (
		SELECT
			CASE
				WHEN schedule_type = 'Contractor and Temp work' THEN 'Contractor'
				WHEN schedule_type = 'Full-time and Part-time'
				OR schedule_type = 'Full-time, Part-time, and Internship' THEN 'Full-time'
				WHEN schedule_type IS NULL THEN 'Uknown'
				ELSE schedule_type
			END AS hourly_rate_schedule_type,
			count(*) AS number_of_jobs,
			min(salary_hourly::integer)::numeric(10, 2) AS hourly_min,
			avg(salary_hourly::integer)::numeric(10, 2) AS hourly_avg,
			percentile_cont(0.25) WITHIN GROUP (
				ORDER BY
					salary_hourly::integer
			)::numeric(10, 2) AS hourly_25_perc,
			percentile_cont(0.5) WITHIN GROUP (
				ORDER BY
					salary_hourly::integer
			)::numeric(10, 2) AS hourly_median,
			percentile_cont(0.75) WITHIN GROUP (
				ORDER BY
					salary_hourly::integer
			)::numeric(10, 2) AS hourly_75_perc,
			MODE() WITHIN GROUP (
				ORDER BY
					salary_hourly::integer
			)::numeric(10, 2) AS hourly_mode,
			max(salary_hourly)::numeric(10, 2) AS hourly_max
		FROM
			jobs
		WHERE
			salary_hourly IS NOT NULL
			AND salary_hourly ~ E'^\\d+$'
		GROUP BY
			hourly_rate_schedule_type
	)
SELECT
	hourly_rate_schedule_type,
	number_of_jobs,
	cast(hourly_min AS money) AS hourly_min,
	cast(hourly_avg AS money) AS hourly_min,
	cast(hourly_25_perc AS money) AS hourly_25_perc,
	cast(hourly_median AS money) AS hourly_median,
	cast(hourly_75_perc AS money) AS hourly_75_perc,
	cast(hourly_mode AS money) AS hourly_mode,
	cast(hourly_max AS money) AS hourly_max
FROM
	get_hourly_stats;

/*
hourly_rate_schedule_type       | number_of_jobs | hourly_min | hourly_min | hourly_25_perc | hourly_median | hourly_75_perc | hourly_mode | hourly_max
--------------------------------------+----------------+------------+------------+----------------+---------------+----------------+-------------+------------
Contractor                           |           1222 |      $9.00 |     $44.30 |         $26.00 |        $35.00 |         $59.00 |      $30.00 |     $98.00
Full-time                            |             70 |     $15.00 |     $47.83 |         $30.00 |        $45.50 |         $65.00 |      $70.00 |     $95.00
Full-time and Contractor             |              4 |     $48.00 |     $63.25 |         $49.50 |        $62.50 |         $76.25 |      $48.00 |     $80.00
Full-time and Internship             |              1 |     $15.00 |     $15.00 |         $15.00 |        $15.00 |         $15.00 |      $15.00 |     $15.00
Full-time and Temp work              |              1 |     $50.00 |     $50.00 |         $50.00 |        $50.00 |         $50.00 |      $50.00 |     $50.00
Full-time, Contractor, and Temp work |             10 |      $9.00 |     $29.90 |         $16.75 |        $23.50 |         $43.75 |      $22.00 |      $9.00
Full-time, Part-time, and Contractor |              2 |     $20.00 |     $22.50 |         $21.25 |        $22.50 |         $23.75 |      $20.00 |     $25.00
Internship                           |              1 |     $23.00 |     $23.00 |         $23.00 |        $23.00 |         $23.00 |      $23.00 |     $23.00
Part-time                            |             21 |     $12.00 |     $37.43 |         $25.00 |        $30.00 |         $40.00 |      $25.00 |     $80.00
Part-time, Contractor, and Temp work |              2 |     $40.00 |     $60.00 |         $50.00 |        $60.00 |         $70.00 |      $40.00 |     $80.00
Uknown                               |              1 |     $60.00 |     $60.00 |         $60.00 |        $60.00 |         $60.00 |      $60.00 |     $60.00
(11 rows)
*/
-- 8. List basic salary statistics (mean, min, median...) for yearly rates and the specific shedule type.
WITH
	get_yearly_stats AS (
		SELECT
			COALESCE(schedule_type, 'Unknown') AS yearly_rate_schedule_type,
			count(*) AS number_of_jobs,
			min(salary_yearly::float)::numeric(10, 2) AS yearly_min,
			avg(salary_yearly::float)::numeric(10, 2) AS yearly_avg,
			percentile_cont(0.25) WITHIN GROUP (
				ORDER BY
					salary_yearly::float
			)::numeric(10, 2) AS yearly_25_perc,
			percentile_cont(0.5) WITHIN GROUP (
				ORDER BY
					salary_yearly::float
			)::numeric(10, 2) AS yearly_median,
			percentile_cont(0.75) WITHIN GROUP (
				ORDER BY
					salary_yearly::float
			)::numeric(10, 2) AS yearly_75_perc,
			MODE() WITHIN GROUP (
				ORDER BY
					salary_yearly::float
			)::numeric(10, 2) AS yearly_mode,
			max(salary_yearly::float)::numeric(10, 2) AS yearly_max
		FROM
			jobs
		WHERE
			salary_yearly IS NOT NULL
			AND salary_yearly ~ E'^\\d+$'
		GROUP BY
			schedule_type
	)
SELECT
	yearly_rate_schedule_type,
	number_of_jobs,
	cast(yearly_min AS money) AS yearly_min,
	cast(yearly_avg AS money) AS yearly_min,
	cast(yearly_25_perc AS money) AS yearly_25_perc,
	cast(yearly_median AS money) AS yearly_median,
	cast(yearly_75_perc AS money) AS yearly_75_perc,
	cast(yearly_mode AS money) AS yearly_mode,
	cast(yearly_max AS money) AS yearly_max
FROM
	get_yearly_stats;

/*
yearly_rate_schedule_type | number_of_jobs | yearly_min  | yearly_min  | yearly_25_perc | yearly_median | yearly_75_perc | yearly_mode | yearly_max
---------------------------+----------------+-------------+-------------+----------------+---------------+----------------+-------------+-------------
Contractor                |             16 |  $55,000.00 |  $99,750.00 |     $72,500.00 |    $80,500.00 |    $118,750.00 |  $72,500.00 | $175,000.00
Full-time                 |            672 |  $30,000.00 |  $99,065.11 |     $75,000.00 |    $95,000.00 |    $112,500.00 | $100,000.00 | $300,000.00
Full-time and Contractor  |              3 |  $95,000.00 | $104,166.67 |     $98,750.00 |   $102,500.00 |    $108,750.00 |  $95,000.00 | $115,000.00
Full-time and Internship  |              2 |  $87,000.00 |  $93,500.00 |     $90,250.00 |    $93,500.00 |     $96,750.00 |  $87,000.00 | $100,000.00
Full-time and Part-time   |              9 |  $60,000.00 |  $91,443.67 |     $75,000.00 |    $88,593.00 |    $100,000.00 | $100,000.00 | $155,000.00
Full-time and Temp work   |              2 | $110,000.00 | $135,000.00 |    $122,500.00 |   $135,000.00 |    $147,500.00 | $110,000.00 | $160,000.00
Internship                |              2 |  $40,000.00 |  $40,000.00 |     $40,000.00 |    $40,000.00 |     $40,000.00 |  $40,000.00 |  $40,000.00
Part-time                 |             11 |  $37,300.00 |  $89,754.55 |     $50,000.00 |   $100,000.00 |    $130,000.00 | $130,000.00 | $130,000.00
Part-time and Contractor  |              1 |  $60,734.00 |  $60,734.00 |     $60,734.00 |    $60,734.00 |     $60,734.00 |  $60,734.00 |  $60,734.00
Temp work                 |              2 |  $65,000.00 |  $82,500.00 |     $73,750.00 |    $82,500.00 |     $91,250.00 |  $65,000.00 | $100,000.00
(10 rows)
*/
-- 9. List the top 5 most frequently required technical skills and the overall frequency percentage.
WITH
	get_skills AS (
		SELECT
			UNNEST(
				replace(replace(description_tokens, '[', '{'), ']', '}')::TEXT []
			) AS technical_skills
		FROM
			jobs
		WHERE
			idx ~ E'^\\d+$'
	)
SELECT
	technical_skills,
	count(*) AS frequency,
	(
		100 * count(*)::float / (
			SELECT
				*
			FROM
				get_record_count
		)
	)::numeric(10, 2) AS freq_perc
FROM
	get_skills
GROUP BY
	technical_skills
ORDER BY
	frequency DESC
LIMIT
	5;

/*
technical_skills | frequency | freq_perc
------------------+-----------+-----------
'sql'            |     23138 |     50.89
'excel'          |     15047 |     33.09
'python'         |     13531 |     29.76
'power_bi'       |     12762 |     28.07
'tableau'        |     12413 |     27.30
(5 rows)*/
-- 10. List the top 20 companies with the most job postings.
SELECT
	initcap(company_name) AS company_name,
	count(*) AS number_of_posts
FROM
	jobs
GROUP BY
	company_name
ORDER BY
	number_of_posts DESC
LIMIT
	20;

/*
company_name               | number_of_posts
-----------------------------------------+-----------------
Upwork                                  |            6570
Talentify.Io                            |            1453
Walmart                                 |            1451
Edward Jones                            |             746
Corporate                               |             612
Dice                                    |             594
Cox Communications                      |             527
Insight Global                          |             393
Centene Corporation                     |             219
Staffigo Technical Services, Llc        |             167
Harnham                                 |             145
Saint Louis County Clerks Office        |             137
Careerbuilder                           |             136
Apex Systems                            |             126
State Of Missouri                       |             120
General Dynamics Information Technology |             116
Jobot                                   |             111
Elevance Health                         |             111
Sam'S Club                              |             108
Unitedhealth Group                      |             102
(20 rows)
*/
-- 11. List the top 10 Job titles.
SELECT
	CASE
		WHEN title LIKE '%sr%'
		OR title LIKE '%iv%'
		OR title LIKE '%senior data%' THEN 'Senior Data Analyst'
		WHEN title LIKE '%lead%'
		OR title = 'data analyst 2'
		OR title LIKE '%iii%'
		OR title LIKE '%ii%' THEN 'Mid-Level Data Analyst'
		WHEN title IN (
			'business intelligence analyst',
			'business analyst',
			'business systems data analyst',
			'bi data analyst'
		) THEN 'Business Data Analyst'
		WHEN title = 'entry level data analyst'
		OR title IN (
			'jr. data analyst',
			'jr data analyst',
			'data analyst i',
			'data analyst 1'
		) THEN 'Junior Data Analyst'
		WHEN title IN (
			'data analyst (remote)',
			'data analyst - contract to hire',
			'data analyst - remote',
			'remote data analyst',
			'data analyst - now hiring',
			'analyst',
			'data analysis'
		) THEN 'Data Analyst'
		ELSE initcap(title)
	END AS job_titles,
	count(*) title_count
FROM
	jobs
GROUP BY
	job_titles
ORDER BY
	title_count DESC
LIMIT
	10;

/*
job_titles               | title_count
----------------------------------------+-------------
Data Analyst                           |        5639
Senior Data Analyst                    |        2249
Data Scientist                         |         687
Data Analyst Ii                        |         536
Business Data Analyst                  |         436
Lead Data Analyst                      |         397
Data Engineer                          |         288
Sr. Data Analyst, Marketing Operations |         271
Data Analyst Iii                       |         264
Business Intelligence Analyst          |         259
(10 rows)
*/
-- 12. List the frequency of benefits listed in the extentions column.
WITH
	get_all_extensions AS (
		SELECT
			UNNEST(
				replace(replace(extensions, '[', '{'), ']', '}')::TEXT []
			) AS benefits,
			count(*) AS benefits_count
		FROM
			jobs
		GROUP BY
			benefits
	)
SELECT
	trim(
		BOTH ''''
		FROM
			benefits
	) AS benefits,
	benefits_count
FROM
	get_all_extensions
WHERE
	--benefits !~ '[0-9]+'
	trim(
		BOTH ''''
		FROM
			benefits
	) IN (
		'Health insurance',
		'Dental insurance',
		'Paid time off'
	)
ORDER BY
	benefits_count DESC
LIMIT
	10;

/*
      benefits    | benefits_count
------------------+----------------
 Health insurance |          15272
 Paid time off    |           9990
 Dental insurance |           9783
(3 rows)
*/
-- 13. List the first 10 companies and the combination of benefits they provide.
DROP TABLE IF EXISTS company_benefits;

CREATE TEMP TABLE company_benefits AS (
	WITH
		get_all_extensions AS (
			SELECT
				data_job_id,
				company_name,
				UNNEST(
					replace(replace(extensions, '[', '{'), ']', '}')::TEXT []
				) AS benefits
			FROM
				jobs
		)
	SELECT
		data_job_id,
		initcap(company_name) AS company_name,
		array_agg(trim(both '''' from benefits)) AS benefits
	FROM
		get_all_extensions
	WHERE
		benefits !~ '[0-9]+'
	GROUP BY
		data_job_id,
		company_name
);

SELECT
	company_name,
	benefits
FROM
	company_benefits
LIMIT
	10;

/*
            company_name            |                                                 benefits

------------------------------------+----------------------------------------------------------------------------------------------------------
 Chloeta                            | {"Paid time off","Dental insurance",Full-time,"Health insurance"}
 Upwork                             | {"No degree mentioned",Contractor,"Work from home"}
 Atc                                | {Full-time,"Health insurance"}
 Guidehouse                         | {Full-time,"Health insurance","Dental insurance"}
 Anmed Health Llc                   | {Part-time,"Health insurance","Work from home","Dental insurance"}
 Oregon Health & Science University | {"Work from home",Full-time}
 Coinbase                           | {"Health insurance","No degree mentioned",Full-time,"Work from home","Paid time off","Dental insurance"}
 Caci International                 | {Full-time}
 Prime Team Partners                | {"Dental insurance","Health insurance",Full-time,"Work from home"}
 Aara Technologies, Inc             | {Full-time}
(10 rows)
*/
-- 14. website wise number of job postings.(helps to choose to best website for quick job search)
SELECT
	trim(
		LEADING 'via '
		FROM
			VIA
	) as platfrom,
	count(VIA) AS WEB_COUNT
FROM
	JOBS
GROUP BY
	VIA
ORDER BY
	WEB_COUNT DESC
LIMIT
	10;

/*
    platfrom     | web_count
------------------+-----------
 LinkedIn         |     16551
 Upwork           |      6548
 BeBee            |      5377
 Trabajo.org      |      3017
 ZipRecruiter     |      2446
 Indeed           |      1684
 Snagajob         |       938
 Jobs Trabajo.org |       810
 Adzuna           |       659
 Built In         |       374
(10 rows)
*/
-- 15. List monthly job postings in year of 2023 in chronological order.
WITH
	get_monthly_jobs AS (
		SELECT
			to_char(date::date, 'Month') AS job_month,
			count(*) AS job_count
		FROM
			jobs
		WHERE
			EXTRACT(
				'year'
				FROM
					date::date
			) = 2023
		GROUP BY
			job_month
	)
SELECT
	job_month,
	job_count,
	round(
		100 * (
			job_count - LAG(job_count) OVER (
				ORDER BY
					to_date(job_month, 'Month')
			)
		) / LAG(job_count) OVER (
			ORDER BY
				to_date(job_month, 'Month')
		)::numeric,
		2
	) AS month_over_month
FROM
	get_monthly_jobs
ORDER BY
	to_date(job_month, 'Month');

/*
job_month | job_count | month_over_month
-----------+-----------+------------------
January   |      3682 |
February  |      2828 |           -23.19
March     |      2727 |            -3.57
April     |      2493 |            -8.58
May       |      2357 |            -5.46
June      |      2362 |             0.21
July      |      2560 |             8.38
August    |      3008 |            17.50
September |      3085 |             2.56
October   |      3364 |             9.04
November  |      2600 |           -22.71
December  |      2345 |            -9.81
(12 rows)

*/
-- 16. List monthly job postings in year of 2024 in chronological order.
WITH
	get_monthly_jobs AS (
		SELECT
			to_char(date::date, 'Month') AS job_month,
			count(*) AS job_count
		FROM
			jobs
		WHERE
			EXTRACT(
				'year'
				FROM
					date::date
			) = 2024
		GROUP BY
			job_month
	)
SELECT
	job_month,
	job_count,
	round(
		100 * (
			job_count - LAG(job_count) OVER (
				ORDER BY
					to_date(job_month, 'Month')
			)
		) / LAG(job_count) OVER (
			ORDER BY
				to_date(job_month, 'Month')
		)::numeric,
		2
	) AS month_over_month
FROM
	get_monthly_jobs
ORDER BY
	to_date(job_month, 'Month');

/*
job_month | job_count | month_over_month
-----------+-----------+------------------
January   |      2296 |
February  |      2534 |            10.37
March     |      1662 |           -34.41
(3 rows)
*/
-- 17. List the top 5 days with the highest number of job postings.
WITH
	get_day_count AS (
		SELECT
			date::date AS single_day,
			count(*) AS daily_job_count,
			DENSE_RANK() OVER (
				ORDER BY
					count(*) DESC
			) AS rnk
		FROM
			jobs
		GROUP BY
			date::date
		ORDER BY
			single_day
	)
SELECT
	single_day,
	daily_job_count
FROM
	get_day_count
WHERE
	rnk < 6
ORDER BY
	rnk;

/*
single_day | daily_job_count
------------+-----------------
2022-11-04 |             279
2022-12-29 |             230
2022-12-03 |             165
2022-12-20 |             160
2023-01-07 |             158
(5 rows)
*/
-- 18. List the top 10 job location where employee needs to report. 
WITH
	trimmed_location AS (
		SELECT
			trim(
				BOTH ' '
				FROM
					job_location
			) AS job_location
		FROM
			jobs
	)
SELECT
	job_location,
	count(job_location) AS job_opportunities
FROM
	trimmed_location
GROUP BY
	job_location
ORDER BY
	job_opportunities DESC
LIMIT
	10;

/*
    job_location    | job_opportunities
--------------------+-------------------
 Anywhere           |             21080
 United States      |             12373
 Kansas City, MO    |              1249
 Oklahoma City, OK  |              1235
 Jefferson City, MO |               855
 Bentonville, AR    |               514
 Tulsa, OK          |               459
 Wichita, KS        |               430
 Topeka, KS         |               370
 Overland Park, KS  |               369
(10 rows)
*/
-- 19. Using the current temp table, list the first 10 companies and the combination of benefits they provide in a table format.

SELECT
	company_name,
	CASE
		WHEN ('Health insurance' = ANY(benefits)) = TRUE THEN 'Yes'
		ELSE 'No'
	END AS health_insurance,
	CASE
		WHEN ('Dental insurance' = ANY(benefits)) = TRUE THEN 'Yes'
		ELSE 'No'
	END AS dental_insurance,
	CASE
		WHEN ('Paid time off' = ANY(benefits)) = TRUE THEN 'Yes'
		ELSE 'No'
	END AS paid_time_off
FROM
	company_benefits
LIMIT 10;
--Note: In all above all queries limit is used for a better view. It can be removed for complete view of Data.
/*
                                           company_name                                           | health_insurance | dental_insurance | paid_time_off
--------------------------------------------------------------------------------------------------+------------------+------------------+---------------
 Chloeta                                                                                          | Yes              | Yes              | Yes
 Upwork                                                                                           | No               | No               | No
 Atc                                                                                              | Yes              | No               | No
 Guidehouse                                                                                       | Yes              | Yes              | No
 Anmed Health Llc                                                                                 | Yes              | Yes              | No
 Oregon Health & Science University                                                               | No               | No               | No
 Coinbase                                                                                         | Yes              | Yes              | Yes
 Caci International                                                                               | No               | No               | No
 Prime Team Partners                                                                              | Yes              | Yes              | No
 Aara Technologies, Inc                                                                           | No               | No               | No
 Amplify                                                                                          | Yes              | Yes              | Yes
*/