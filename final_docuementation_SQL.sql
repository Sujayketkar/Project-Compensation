-- Database: documentation_Compensation_Project

-- DROP DATABASE IF EXISTS "documentation_Compensation_Project";

CREATE DATABASE "documentation_Compensation_Project"
    WITH
    OWNER = postgres
    ENCODING = 'UTF8'
    LC_COLLATE = 'English_United States.1252'
    LC_CTYPE = 'English_United States.1252'
    LOCALE_PROVIDER = 'libc'
    TABLESPACE = pg_default
    CONNECTION LIMIT = -1
    IS_TEMPLATE = False;
	
	
CREATE TABLE Salaries(
Start_Year VARCHAR(50),
Start_Date DATE,
Employee_Name VARCHAR(50),
unique_ID VARCHAR(50),
Level_ID  VARCHAR(50),
Grade VARCHAR(50),
Project VARCHAR(50),
Current_Base_Pay numeric,
Bonus_entitlement numeric,
Rating numeric
	
)


select * FROM Salaries
WHERE unique_id = '557'



SELECT count(distinct unique_id) FROM Salaries;


------------------------------------ employee count as per grade-------------------------------------------

select grade, 
count(distinct unique_id) as employees
FROM Salaries
GROUP BY grade;


------------------------------------employee project allocation & grade(intermediate)-----------------------------

select grade, 
COUNT( CASE WHEN project = 'Tokyo' THEN unique_id END) AS Tokyo,
COUNT( CASE WHEN project = 'Venice' THEN unique_id END) AS Venice,
COUNT( CASE WHEN project = 'Gemcon' THEN unique_id END) AS Gemcon
FROM 
Salaries
GROUP BY 
grade
ORDER BY 
grade;


----------------------------------average ratings across projects------------------------------------------------

select grade, 
ROUND(AVG( CASE WHEN project = 'Tokyo' THEN rating END),2) AS Tokyo,
ROUND(AVG( CASE WHEN project = 'Venice' THEN rating END),2) AS Venice,
ROUND(AVG( CASE WHEN project = 'Gemcon' THEN rating END),2) AS Gemcon
FROM 
Salaries
GROUP BY 
grade
ORDER BY 
grade;



---------------------------Average Base Pay across projects and grade----------------------------------------
select grade, 
ROUND(AVG( CASE WHEN project = 'Tokyo' THEN current_Base_Pay END),0) AS Tokyo,
ROUND(AVG( CASE WHEN project = 'Venice' THEN current_Base_Pay  END),0) AS Venice,
ROUND(AVG( CASE WHEN project = 'Gemcon' THEN current_Base_Pay  END),0) AS Gemcon
FROM 
Salaries
GROUP BY 
grade
ORDER BY 
grade;



--------------------------------Percentile calculation--------------------------------------------------
ALTER TABLE Salaries
ADD COLUMN percentile_category VARCHAR(50);

WITH Percentiles AS (
    SELECT 
        *,
        PERCENT_RANK() OVER (PARTITION BY grade ORDER BY current_base_pay) AS percentile_rank
    FROM 
        Salaries
)
UPDATE Salaries AS s
SET percentile_category =
    CASE 
        WHEN p.percentile_rank <= 0.25 THEN 'Below 25th'
        WHEN p.percentile_rank <= 0.50 THEN 'Between 25th to 50th'
        WHEN p.percentile_rank <= 0.75 THEN 'Between 50th to 75th'
        ELSE 'Above 75th'
    END
FROM 
    Percentiles AS p
WHERE 
    s.unique_id = p.unique_id;


select * FROM Salaries


----now we wish to see no of employees in percentile rank vs project-----------------------

select percentile_category, 
COUNT( CASE WHEN project = 'Tokyo' THEN unique_id END) AS Tokyo,
COUNT( CASE WHEN project = 'Venice' THEN unique_id END) AS Venice,
COUNT( CASE WHEN project = 'Gemcon' THEN unique_id END) AS Gemcon
FROM 
Salaries
GROUP BY 
percentile_category
ORDER BY 
percentile_category;


----now we wish to see no of employees in percentile rank vs grade-----------------------
 
select percentile_category, 
COUNT( CASE WHEN grade = 'Associate' THEN unique_id END) AS Associate,
COUNT( CASE WHEN grade = 'Software Engineer' THEN unique_id END) AS Software_Engineer,
COUNT( CASE WHEN grade = 'Senior Software Engineer' THEN unique_id END) AS Senior_Software_Engineer,
COUNT( CASE WHEN grade = 'Lead Engineer' THEN unique_id END) AS Lead_Engineer
FROM 
Salaries
GROUP BY 
percentile_category
ORDER BY 
percentile_category;


----------------------------------------years in the company-----------------------------------------------------------


-- Add a new column for time_in_company
ALTER TABLE Salaries
ADD COLUMN time_in_company NUMERIC;

-- Update the newly added column with the time difference in years and months

 UPDATE Salaries
SET time_in_company = 
    ROUND(
        EXTRACT(YEAR FROM AGE('2024-04-01', start_date))::NUMERIC +
        EXTRACT(MONTH FROM AGE('2024-04-01', start_date))/12, 2
    );
	

---this time in the company will come in handy when we dole out bonus basis time spent----------

------below calculations are to calculate prorated salaries mainly affecting those with <1 tenure

-- Add a new column for prorated
ALTER TABLE Salaries
ADD COLUMN prorated NUMERIC;

-- Update the newly added column based on the condition
UPDATE Salaries
SET prorated = 
    CASE 
        WHEN time_in_company >= 1 THEN 1
        ELSE time_in_company
    END;

----the above query will ensure that our final output will continue to adhere to prorated details.


----calculate regular bonus-------------------------------------

-- Add a new column for regular_bonus
ALTER TABLE Salaries
ADD COLUMN regular_bonus NUMERIC;

-- Update the newly added column based on the conditions
UPDATE Salaries
SET regular_bonus = 
    Round(
		CASE 
        WHEN project IN ('Venice', 'Tokyo') AND rating >= 7 THEN current_base_pay * bonus_entitlement * prorated
        ELSE current_base_pay * bonus_entitlement * prorated * 0.5
    END,2
);


 
-----how much are we distributing as a regular bonus

select sum(regular_bonus) FROM  Salaries;

select ROUND(AVG(regular_bonus),2) FROM  Salaries;

---------------------Additional Bonus----------------------------------

ALTER TABLE Salaries
ADD COLUMN Additional_Bonus numeric;



-- Update the newly added column based on the conditions

 

UPDATE Salaries
SET Additional_Bonus = 
    CASE 
        WHEN project = 'Venice' AND time_in_company >= 3 AND rating >= 7 THEN 50000
        WHEN project = 'Venice' AND time_in_company >= 2 AND time_in_company < 3 AND rating >= 7 THEN 25000
        WHEN project = 'Tokyo' AND time_in_company >= 3 AND rating >= 7 THEN 20000
        WHEN project = 'Tokyo' AND time_in_company >= 2 AND time_in_company < 3 AND rating >= 7 THEN 10000
        ELSE 0
    END;



-----------------TOTAL_BONUS PAYOUT----------------------------------------------------------

ALTER TABLE Salaries
ADD COLUMN Total_Bonus numeric;

UPDATE Salaries
SET Total_bonus = regular_bonus + additional_bonus;



----------------------Now we set to display salary revision data------------------------------------

ALTER TABLE Salaries
ADD COLUMN Hike_percent numeric;

 


UPDATE Salaries
SET Hike_percent= 
    CASE 
        WHEN project = 'Venice' AND percentile_category='Below 25th' AND rating >= 7 THEN 0.18
        WHEN project = 'Venice' AND percentile_category='Between 25th to 50th' AND rating >= 7 THEN 0.18
		WHEN project = 'Venice' AND percentile_category='Between 50th to 75th' AND rating >= 7 THEN 0.12
		WHEN project = 'Venice' AND percentile_category='Above 75th' AND rating >= 7 THEN 0.12
        WHEN project = 'Tokyo' AND  percentile_category='Below 25th' AND rating >= 7 THEN 0.12
        WHEN project = 'Tokyo' AND  percentile_category='Between 25th to 50th' AND rating >= 7 THEN 0.12
		WHEN project = 'Tokyo' AND  percentile_category='Between 50th to 75th' AND rating >= 7 THEN 0.10
        WHEN project = 'Tokyo' AND  percentile_category='Above 75th' AND rating >= 7 THEN 0.10
		ELSE 0.05
    END;





---------------------New Base Pay------------------------------------------------

ALTER TABLE Salaries
ADD COLUMN New_Base_Pay numeric;


UPDATE Salaries
SET New_Base_Pay  = ROUND(Current_base_pay +(current_base_pay*prorated*hike_percent),0)



SELECT grade,Project, rating, prorated, current_base_pay, new_base_pay,total_bonus FROM Salaries
WHERE grade = 'Associate' AND project = 'Gemcon'

 











