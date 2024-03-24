

DROP TABLE IF EXISTS public.jobs;

CREATE TABLE public.jobs (
	data_job_id INT,
	idx TEXT,
	title TEXT,
	company_name TEXT,
	job_location TEXT,
	via TEXT,
	description TEXT,
	extensions TEXT,
	job_id TEXT,
	thumbnail TEXT,
	posted_at TEXT,
	schedule_type TEXT,
	work_from_home TEXT,
	salary TEXT,
	search_term TEXT,
	date TEXT,
	time TEXT,
	search_location TEXT,
	commute_time TEXT,
	salary_pay TEXT,
	salary_rate TEXT,
	salary_avg TEXT,
	salary_min TEXT,
	salary_max TEXT,
	salary_hourly TEXT,
	salary_yearly TEXT,
	salary_standardized TEXT,
	description_tokens TEXT,
	PRIMARY KEY (data_job_id)
);


COPY public.jobs FROM '/tmp/gsearch_jobs.csv' DELIMITER ',' CSV HEADER;
