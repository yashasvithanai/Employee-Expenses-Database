-- DROP DATABASE expense;
CREATE DATABASE IF NOT EXISTS expense;

USE expense;

SELECT * FROM account_codes;
SELECT * FROM dept_codes;
SELECT * FROM employees;
SELECT * FROM expenses;
SELECT * FROM reason_codes;
SELECT * FROM reimbursements;
SELECT * FROM trips;

SELECT employee, trip_id, account_no, Sum(gross_amount) as trip_expense
FROM expenses
GROUP BY employee, trip_id;


CREATE TABLE datawarehouse (
SELECT expenses.employee, department.dept, expenses.trip_id, trips.reason_code, expenses.account_no, SUM(expenses.gross_amount) as trip_expense, reimbursements.reimbursement_amount
FROM expenses 
JOIN trips 
ON expenses.trip_id = trips.trip_id AND expenses.employee = trips.employee
JOIN (SELECT ssn, dept FROM employees) AS department 
ON department.ssn = expenses.employee
JOIN reimbursements 
ON reimbursements.employee = expenses.employee AND reimbursements.trip_id = expenses.trip_id
GROUP BY employee, trip_id
ORDER BY dept, employee, trip_id); 



SELECT * FROM datawarehouse;

-- general stats
-- Total expenses and reimbursements by department and employee
SELECT dept, employee, SUM(trip_expense) AS total_expense , SUM(reimbursement_amount) AS total_reimbursement
FROM datawarehouse
GROUP BY dept, employee WITH ROLLUP ;

-- Total expenses and reimbursements by department and reason
SELECT dept, reason_code, SUM(trip_expense) AS total_expense , SUM(reimbursement_amount) AS total_reimbursement
FROM datawarehouse
GROUP BY dept, reason_code WITH ROLLUP ;

-- Total trips by department
SELECT dept, COUNT(dept) AS total_dept_trips
FROM datawarehouse 
GROUP BY dept
ORDER BY total_dept_trips DESC;

-- Total number of distinct trips
SELECT COUNT(DISTINCT trip_id)
FROM datawarehouse; 

-- total expenses by employee
SELECT employee, SUM(trip_expense) AS total_expense, COUNT(employee) AS no_of_trips, AVG(trip_expense) AS avg_expense
FROM datawarehouse
GROUP BY employee
ORDER BY avg_expense DESC;


-- Insight 1
-- Computing the average expenses of each employee and the average number of days they take on their trips for each reason of the trip
SELECT datawarehouse.employee, datawarehouse.trip_id, datawarehouse.reason_code, reason_codes.reason_description,  AVG(trip_expense) AS average_expense, 
AVG(DATEDIFF(str_to_date(trips.end_date, "%m/%d/%Y"), str_to_date(trips.start_date, "%m/%d/%Y"))) AS average_days
FROM datawarehouse 
JOIN trips 
ON datawarehouse.employee = trips.employee AND datawarehouse.trip_id = trips.trip_id
LEFT JOIN reason_codes
ON reason_codes.reason_code = datawarehouse.reason_code
GROUP BY employee, reason_code
ORDER BY employee, reason_code; 


-- Insight 2
-- Calculating department wise total expenses, total trips, and average expense.
SELECT datawarehouse.dept, dept_codes.dept_name, SUM(trip_expense) AS total_dept_expense, COUNT(dept) AS total_dept_trips, AVG(trip_expense) AS average_dept_expense
FROM datawarehouse 
JOIN dept_codes
ON datawarehouse.dept = dept_codes.dept_id
GROUP BY datawarehouse.dept
ORDER BY total_dept_expense DESC;


-- Insight 3
-- To find out the reason for which a department takes the maximum trips

-- First, calculating the frequency of each reason for which each department takes trips 
-- (which will be included as a sub query for this solution)
SELECT dept, dept_reason_frequency.reason_code, no_of_trips, reason_description
FROM reason_codes
RIGHT JOIN (SELECT dept, reason_code, (COUNT(reason_code)) AS no_of_trips
FROM datawarehouse 
GROUP BY dept, reason_code
ORDER BY dept, no_of_trips DESC) AS dept_reason_frequency 
ON reason_codes.reason_code = dept_reason_frequency.reason_code;


-- Using the above query to find reason for which each department takes maximum trips.
SELECT dept, max_reason_freq, temp.reason_code, reason_description
FROM (SELECT dept, Max(no_of_trips) as max_reason_freq, reason_code
FROM (SELECT dept, dept_reason_frequency.reason_code, no_of_trips, reason_description
FROM reason_codes
RIGHT JOIN (SELECT dept, reason_code, (COUNT(reason_code)) AS no_of_trips
FROM datawarehouse 
GROUP BY dept, reason_code
ORDER BY dept, no_of_trips DESC) AS dept_reason_frequency 
ON reason_codes.reason_code = dept_reason_frequency.reason_code) AS reason_frequency
GROUP BY dept) AS temp
JOIN reason_codes
ON reason_codes.reason_code = temp.reason_code
order by dept;

-- Insight 4
-- Calculating total rows in the datawarehouse which have
-- 1. settled reimbursement
-- 2. reimbursement amount less than expense
-- 3. not yet been reimbursed

-- This query adds a column to our warehouse calculating the difference between expenses from employee trips and reimbursement amounts 
-- (which will be used as a subquery for our solution)
SELECT dept, reason_code, Count(reason_code) AS no_of_trips
from datawarehouse 
group by dept, reason_code
Order by no_of_trips DESC , dept ;


SELECT datawarehouse.employee, datawarehouse.dept, datawarehouse.trip_id, datawarehouse.reason_code, datawarehouse.account_no, 
datawarehouse.trip_expense, datawarehouse.reimbursement_amount,
datawarehouse.trip_expense - datawarehouse.reimbursement_amount AS difference ,
    case 
    when datawarehouse.trip_expense - datawarehouse.reimbursement_amount > 0 and datawarehouse.reimbursement_amount > 0 then 'reimbursement_amount less than trip expense'
    when datawarehouse.trip_expense - datawarehouse.reimbursement_amount = 0  then 'amount settled'
    when datawarehouse.trip_expense - datawarehouse.reimbursement_amount > -1 AND datawarehouse.trip_expense - datawarehouse.reimbursement_amount < 0 then 'amount settled'
    else 'reimbursement_amount pending'
    end as reimbursement_status
FROM datawarehouse
ORDER BY difference DESC, trip_expense DESC;

-- The query above is being used in the following query 
-- to calculate the total 
-- 1. rows which have settled balances,
-- 2. rows which were reimbursed lesser amount than expenses
-- 3. rows which are yet to be reimbursed.

SELECT reimbursement_status, COUNT(reimbursement_status)
FROM (SELECT datawarehouse.employee, datawarehouse.dept, datawarehouse.trip_id, datawarehouse.reason_code, datawarehouse.account_no, 
datawarehouse.trip_expense, datawarehouse.reimbursement_amount,
datawarehouse.trip_expense - datawarehouse.reimbursement_amount AS difference,
    CASE 
    WHEN datawarehouse.trip_expense - datawarehouse.reimbursement_amount > 0 AND datawarehouse.reimbursement_amount > 0 THEN 'reimbursement_amount less than trip expense'
    WHEN datawarehouse.trip_expense - datawarehouse.reimbursement_amount = 0  THEN 'amount settled'
    WHEN datawarehouse.trip_expense - datawarehouse.reimbursement_amount > -1 AND datawarehouse.trip_expense - datawarehouse.reimbursement_amount < 0 THEN 'amount settled'
    ELSE 'reimbursement_amount pending'
    END AS reimbursement_status
FROM datawarehouse
ORDER BY difference DESC, trip_expense DESC) AS datawarehouse_2
GROUP BY reimbursement_status;



