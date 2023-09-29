-- 1.a. Which prescriber had the highest total number of claims (totaled over all drugs)?
-- Report the npi and the total number of claims.
SELECT npi, total_claim_count
FROM prescription
ORDER BY total_claim_count DESC
LIMIT 1;

-- 1.b. Repeat the above, but this time report the nppes_provider_first_name, 
-- nppes_provider_last_org_name, specialty_description, and the total number of claims.
SELECT nppes_provider_first_name, 
	   nppes_provider_last_org_name,
	   specialty_description, 
	   total_claim_count
FROM prescription rx
	LEFT JOIN prescriber p
		ON rx.npi = p.npi
ORDER BY total_claim_count DESC
LIMIT 1;

-------------------------------------------------------------------------------------------------
-- 2.a. Which specialty had the most total number of claims (totaled over all drugs)?
SELECT specialty_description, SUM(total_claim_count) AS num_claims
FROM prescription 
	LEFT JOIN prescriber
		USING(npi)
GROUP BY specialty_description
ORDER BY num_claims DESC
LIMIT 1;

-- 2.b. Which specialty had the most total number of claims for opioids?
SELECT specialty_description,
	   SUM(total_claim_count) AS total_opioids
FROM prescriber
	FULL JOIN prescription
		USING(npi)
	FULL JOIN drug
		USING(drug_name)
WHERE opioid_drug_flag = 'Y'
GROUP BY specialty_description
ORDER BY total_opioids DESC NULLS LAST
LIMIT 1;

-- 2.c. Are there any specialties that appear in the prescriber table 
-- that have no associated prescriptions in the prescription table?
SELECT specialty_description, SUM(total_claim_count) AS total_claims
FROM prescriber
	FULL JOIN prescription
		USING(npi)
GROUP BY specialty_description
HAVING SUM(total_claim_count) IS NULL;

-- 2.d. For each specialty, report the percentage of total claims by that specialty which are for opioids. 
-- Which specialties have a high percentage of opioids?
WITH total_claims_by_specialty AS (SELECT specialty_description, SUM(total_claim_count) AS total_claims
								   FROM prescriber
								   	INNER JOIN prescription
										USING(npi)
								   GROUP BY specialty_description)

SELECT specialty_description, (ROUND((total_opioid_claims::decimal/total_claims::decimal), 4)*100) AS percent_claims_for_opioids
-- this table is opioid_claims_by_specialty
FROM (SELECT specialty_description, SUM(total_claim_count) AS total_opioid_claims
	  FROM prescriber
	  	INNER JOIN prescription
			USING(npi)
		INNER JOIN drug
			USING(drug_name)
		WHERE opioid_drug_flag = 'Y'
		GROUP BY specialty_description) AS opioid_claims_by_specialty
-- Join total_claims_by_specialty
	RIGHT JOIN total_claims_by_specialty
		USING(specialty_description)
ORDER BY percent_claims_for_opioids DESC NULLS last

-------------------------------------------------------------------------------------------------
-- 3.a. Which drug (generic_name) had the highest total drug cost?
SELECT generic_name, total_drug_cost
FROM drug
	INNER JOIN prescription
		USING(drug_name)
ORDER BY total_drug_cost DESC
LIMIT 1;

-- 3.b. Which drug (generic_name) has the hightest total cost per day (rounded to two decimal places)?
SELECT generic_name, ROUND(SUM(total_drug_cost) / SUM(total_day_supply), 2) AS total_cost_per_day
FROM prescription 
	INNER JOIN drug
		USING(drug_name)
GROUP BY generic_name
ORDER BY total_cost_per_day DESC
LIMIT 1;

-------------------------------------------------------------------------------------------------
-- 4.a. For each drug in the drug table, return the drug name and then a column named 'drug_type' which says 
-- 'opioid' for drugs which have opioid_drug_flag = 'Y', says 'antibiotic' for those drugs which have 
-- antibiotic_drug_flag = 'Y', and says 'neither' for all other drugs.
SELECT drug_name,
	   CASE WHEN opioid_drug_flag = 'Y' THEN 'opioid'
	   		WHEN antibiotic_drug_flag = 'Y' THEN 'antibiotic'
			ELSE 'neither' END AS drug_type
FROM drug;


--4.b. Building off of the query you wrote for part a, determine whether more was spent (total_drug_cost) 
-- on opioids or on antibiotics. Hint: Format the total costs as MONEY for easier comparision.
SELECT CASE WHEN opioid_drug_flag = 'Y' THEN 'opioid'
	   		WHEN antibiotic_drug_flag = 'Y' THEN 'antibiotic'
			ELSE 'neither' END AS drug_type, 
			CAST(SUM(total_drug_cost) AS MONEY) AS total_cost
FROM drug d
	INNER JOIN prescription p
		ON d.drug_name = p.drug_name
GROUP BY drug_type
ORDER BY total_cost DESC;

-------------------------------------------------------------------------------------------------
-- 5.a. How many CBSAs are in Tennessee? Warning: The cbsa table contains information for all states, not just Tennessee.
SELECT COUNT(DISTINCT(cbsa))
FROM (SELECT *, RIGHT(cbsaname, 2) AS state
	  FROM cbsa) as cbsa_state
WHERE state = 'TN';

-- 5.b. Which cbsa has the largest combined population? Which has the smallest? Report the CBSA name and total population.
SELECT cbsaname, SUM(population) AS total_population
FROM cbsa
	LEFT JOIN zip_fips
		USING(fipscounty)
	INNER JOIN population
		USING(fipscounty)
GROUP BY cbsaname
ORDER BY total_population DESC;
-- Morristown, TN is the smallest
-- Memphis, TN-MS-AR is the highest

-- 5.c. What is the largest (in terms of population) county which is not included in a CBSA? Report the county name and population.
SELECT county, population, cbsa
FROM cbsa
	RIGHT JOIN fips_county
		USING(fipscounty)
	INNER JOIN population
		USING(fipscounty)
WHERE cbsa IS NULL
ORDER BY population DESC;

-------------------------------------------------------------------------------------------------
-- 6.a. Find all rows in the prescription table where total_claims is at least 3000. Report the drug_name and the total_claim_count.
SELECT drug_name, total_claim_count
FROM prescription
WHERE total_claim_count >= 3000
ORDER BY total_claim_count DESC;

-- 6.b. For each instance that you found in part a, add a column that indicates whether the drug is an opioid.
-- SOLUTION WITH CTE:
WITH high_claims AS (SELECT drug_name, total_claim_count
					 FROM prescription
					 WHERE total_claim_count >= 3000
					 ORDER BY total_claim_count DESC)
SELECT high_claims.drug_name, 
	   total_claim_count,
	   opioid_drug_flag AS opioid
FROM high_claims
	LEFT JOIN drug
		USING(drug_name)
ORDER BY total_claim_count DESC;


-- SOLUTION WITH SUB-QUERY:
SELECT high_claims.drug_name, 
	   total_claim_count,
	   opioid_drug_flag AS opioid
FROM (SELECT drug_name, total_claim_count
	  FROM prescription
	  WHERE total_claim_count >= 3000) AS high_claims
	  	LEFT JOIN drug
			USING(drug_name)
ORDER BY total_claim_count DESC;

-- 6.c. Add another column to you answer from the previous part which gives the prescriber first and last name associated with each row.
-- SOLUTION WITH CTE
WITH high_claims AS (SELECT drug_name, total_claim_count, npi
					 FROM prescription
					 WHERE total_claim_count >= 3000
					 ORDER BY total_claim_count DESC)
SELECT nppes_provider_first_name AS first_name,
	   nppes_provider_last_org_name AS last_name,
	   high_claims.drug_name, 
	   total_claim_count,
	   opioid_drug_flag AS opioid
FROM high_claims
	LEFT JOIN drug
		USING(drug_name)
	LEFT JOIN prescriber p
		USING(npi)
ORDER BY total_claim_count DESC;

-- SOLUTION WITH SUB-QUERY
SELECT nppes_provider_first_name AS first_name,
	   nppes_provider_last_org_name AS last_name,
	   drug_name, 
	   total_claim_count,
	   opioid
FROM (SELECT npi,
	  		 high_claims.drug_name, 
	  		 total_claim_count,
	   		 opioid_drug_flag AS opioid
	  FROM (SELECT drug_name, total_claim_count, npi
	  		FROM prescription
	  		WHERE total_claim_count >= 3000) AS high_claims
	  			LEFT JOIN drug
					USING(drug_name)) AS three_cols
	  	LEFT JOIN prescriber
			USING(npi)
ORDER BY total_claim_count DESC;

-------------------------------------------------------------------------------------------------
-- 7. The goal of this exercise is to generate a full list of all pain management specialists in Nashville and the number 
-- of claims they had for each opioid. Hint: The results from all 3 parts will have 637 rows.

-- 7.a. First, create a list of all npi/drug_name combinations for pain management specialists (specialty_description = 'Pain Managment') 
-- in the city of Nashville (nppes_provider_city = 'NASHVILLE'), where the drug is an opioid (opiod_drug_flag = 'Y'). 
-- Warning: Double-check your query before running it. You will only need to use the prescriber and drug tables 
-- since you don't need the claims numbers yet.
SELECT npi, 
	   drug_name
FROM prescriber 
	CROSS JOIN drug
WHERE specialty_description = 'Pain Management' 
	AND nppes_provider_city = 'NASHVILLE' 
	AND opioid_drug_flag = 'Y'
ORDER BY drug_name;

-- 7.b. Next, report the number of claims per drug per prescriber. Be sure to include all combinations, whether or 
-- not the prescriber had any claims. You should report the npi, the drug name, and the number of claims (total_claim_count).
WITH npi_drug_combine AS (SELECT npi, 
						  		 drug_name
						 FROM prescriber 
							CROSS JOIN drug
						 WHERE specialty_description = 'Pain Management' 
						 	AND nppes_provider_city = 'NASHVILLE' 
							AND opioid_drug_flag = 'Y'
						 ORDER BY drug_name)
SELECT npi_drug_combine.npi, 
	   npi_drug_combine.drug_name, 
	   total_claim_count
FROM npi_drug_combine
	LEFT JOIN prescription p
		ON p.npi = npi_drug_combine.npi AND p.drug_name = npi_drug_combine.drug_name
ORDER BY drug_name;

-- 7.c. Finally, if you have not done so already, fill in any missing values for total_claim_count with 0. 
-- Hint - Google the COALESCE function.
WITH npi_drug_combine AS (SELECT npi, 
						  		 drug_name
						 FROM prescriber 
							CROSS JOIN drug
						 WHERE specialty_description = 'Pain Management' 
						 	AND nppes_provider_city = 'NASHVILLE' 
							AND opioid_drug_flag = 'Y'
						 ORDER BY drug_name)					 
SELECT npi_drug_combine.npi, 
	   npi_drug_combine.drug_name, 
	   COALESCE(total_claim_count, 0) AS total_claim_count
FROM npi_drug_combine
	LEFT JOIN prescription p
		ON p.npi = npi_drug_combine.npi AND p.drug_name = npi_drug_combine.drug_name
ORDER BY drug_name










