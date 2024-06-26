-- Q1- Write a query to print top 5 cities with highest spends and their percentage contribution of total credit card spends

WITH CTE AS
(
SELECT TOP 5 city, SUM(amount) AS highest_spends
FROM credit_card_data
GROUP BY city
ORDER BY highest_spends DESC
),
CTE2 AS
(
SELECT SUM(amount) AS total_amount FROM credit_card_data
)
SELECT CTE.city,CTE.highest_spends,ROUND(100*(CTE.highest_spends/CTE2.total_amount),2) AS percentage_contribution
FROM CTE INNER JOIN CTE2 ON 1=1;

--- SIMPLER ALTERNATE SOLUTION
SELECT TOP 5 city,SUM(amount) AS highest_spends, 
ROUND(100*(SUM(amount)/(SELECT SUM(amount) FROM credit_card_data)),2) AS percentage_contribution
FROM credit_card_data
GROUP BY city
ORDER BY highest_spends DESC;


-- Q2 Write a query to print highest spend month and amount spent in that month for each card type.

WITH highest_spend_month AS
(
SELECT card_type, DATENAME(MONTH,transaction_date) AS MONTH_NAME,
DATEPART(YEAR,transaction_date) AS _YEAR, SUM(amount) AS total_amount
FROM credit_card_data
GROUP BY DATEPART(YEAR,transaction_date),DATENAME(MONTH,transaction_date),card_type
)
,
amount_spent AS
(SELECT *, DENSE_RANK() OVER(PARTITION BY card_type ORDER BY total_amount DESC) AS _rank
FROM highest_spend_month)

SELECT card_type,MONTH_NAME,_YEAR,total_amount
FROM amount_spent
WHERE _rank = 1;

--- ALTERNATE SOLUTION
with CTE as 
(
select card_type, month(transaction_date) AS _month,year(transaction_date) AS _year,
sum(amount) as total_spend 
from credit_card_data
group by card_type,month(transaction_date),year(transaction_date)
)

SELECT * FROM
(
select *, rank() over(partition by card_type order by total_spend desc) as rn
from CTE) AS A
where rn=1;

-- Q3 write a query to print the transaction details(all columns from the table) for each card type when 
--it reaches a cumulative of 1000000 total spends
--(We should have 4 rows in the o/p one for each card type).

-- ordered by amount
WITH CTE AS
(
SELECT*,
SUM(amount) OVER(PARTITION BY card_type ORDER BY transaction_date,amount) AS cumulative_spend
FROM credit_card_data
),
CTE2 AS
(SELECT*, DENSE_RANK() OVER(PARTITION BY card_type ORDER BY cumulative_spend) AS _rank
FROM CTE 
WHERE cumulative_spend >= 1000000)
SELECT * FROM CTE2
WHERE _rank = 1;

--- ALTERNATE SOLUTION (ordered by transaction_id)
WITH CTE AS
(
SELECT*,
SUM(amount) OVER(PARTITION BY card_type ORDER BY transaction_date,transaction_id) AS cumulative_spend
FROM credit_card_data
)
SELECT * FROM
(SELECT *,DENSE_RANK() OVER(PARTITION BY card_type ORDER BY cumulative_spend) AS _rank
FROM CTE
WHERE cumulative_spend >= 1000000) AS A WHERE _rank = 1;

-- Q4 Write a query to find city which had lowest percentage spend for gold card type.

WITH CTE AS
(
SELECT *,
SUM(amount) OVER(PARTITION BY city ORDER BY city) AS city_amount
FROM credit_card_data
WHERE card_type = 'Gold'
)
SELECT TOP 1 city,
ROUND(100*(city_amount/(SELECT SUM(amount) FROM CTE)),2) AS percent_spend
FROM CTE;

---ALTERNATE SOLUTION

WITH CTE1 AS
(
SELECT city,SUM(amount) AS amount_goldcard
FROM credit_card_data
WHERE card_type = 'Gold'
GROUP BY city
),
CTE2 AS
(
SELECT city, SUM(amount) AS total_amount
FROM credit_card_data
GROUP BY city
),
CTE3 AS
(
SELECT CTE1.city, CTE1.amount_goldcard, CTE2.total_amount
, ROUND((100*CTE1.amount_goldcard/CTE2.total_amount),2) AS percent_spend
FROM CTE1
INNER JOIN CTE2
ON CTE1.city = CTE2.city
)

SELECT TOP 1*
FROM CTE3
ORDER BY percent_spend;


--- Q5 Write a query to print 3 columns: city, highest_expense_type , lowest_expense_type (example format : Delhi , bills, Fuel).

WITH CTE1 AS
(
SELECT city, exp_type, SUM(amount) AS exp_type_amount FROM credit_card_data
GROUP BY city, exp_type
),
CTE2 AS
(
SELECT city, MAX(exp_type_amount) AS highest_amount,
MIN(exp_type_amount) AS lowest_amount
FROM CTE1
GROUP BY city
)
SELECT CTE1.city,
MAX(CASE WHEN exp_type_amount = highest_amount THEN exp_type END) AS highest_spend,
MIN(CASE WHEN exp_type_amount = lowest_amount THEN exp_type END) AS lowest_spend
FROM CTE2
INNER JOIN CTE1
ON CTE2.city = CTE1.city
GROUP BY CTE1.city
ORDER BY CTE1.city;

--- ALTERNATE SOLUTION

WITH cte AS 
(
SELECT
city,exp_type,
SUM(amount) AS total_amount,
RANK() OVER (PARTITION BY city ORDER BY SUM(amount) ASC) AS rn_asc,
RANK() OVER (PARTITION BY city ORDER BY SUM(amount) DESC) AS rn_desc
FROM credit_card_data
GROUP BY city, exp_type
)
SELECT city,
MAX(CASE WHEN rn_desc = 1 THEN exp_type END) AS highest_expense_type,
MIN(CASE WHEN rn_asc = 1 THEN exp_type END) AS lowest_expense_type
FROM cte
GROUP BY city;

-- Q6 Write a query to find percentage contribution of spends by females for each expense type

SELECT exp_type,
ROUND(100*(SUM(CASE WHEN Gender = 'F' THEN amount END)/SUM(amount)),2) AS percent_contribution FROM credit_card_data
GROUP BY exp_type;

-- ALTERNATE SOLUTION

WITH CTE1 AS
(
SELECT exp_type,SUM(amount) AS amount_female
FROM credit_card_data
WHERE gender = 'F'
GROUP BY exp_type
),
CTE2 AS
(
SELECT exp_type, SUM(amount) AS total_amount_exptype
FROM credit_card_data
GROUP BY exp_type
)
SELECT CTE1.exp_type,
ROUND((100*CTE1.amount_female/CTE2.total_amount_exptype),2) AS percent_contribution
FROM CTE1
INNER JOIN CTE2
ON CTE1.exp_type = CTE2.exp_type

-- Q7 Which card and expense type combination saw highest month over month growth in Jan-2014

WITH CTE1 AS
(
SELECT card_type, exp_type,
SUM(amount) AS total_amount,
DATEPART(YEAR,transaction_date) AS year_transaction,
DATEPART(MONTH,transaction_date) AS month_transaction
FROM credit_card_data
GROUP BY card_type, exp_type,DATEPART(YEAR,transaction_date),DATEPART(MONTH,transaction_date)
),
CTE2 AS
(
SELECT *,
LAG(total_amount,1) OVER(PARTITION BY card_type, exp_type ORDER BY year_transaction,month_transaction) AS prev_month_trans_amount
FROM CTE1
),
CTE3 AS
(
SELECT *,
ROUND(100*(total_amount-prev_month_trans_amount)/prev_month_trans_amount,2) AS percentage_growth
FROM CTE2
WHERE year_transaction = 2014 AND month_transaction =1)

SELECT TOP 1*
FROM CTE3
ORDER BY percentage_growth DESC;

-- Q8 During weekends which city has highest total spend to total no of transcations ratio
SELECT TOP 1 city,
SUM(amount) AS total_amount,
COUNT(*) AS count_trans,
SUM(amount)/COUNT(*) AS ratio
FROM credit_card_data
WHERE DATEPART(WEEKDAY,transaction_date) IN (7,1)
GROUP BY city
ORDER BY ratio DESC;

-- Q9 Which city took least number of days to reach its 500th transaction after the first transaction in that city
WITH CTE1 AS
(
SELECT city,
COUNT(1) AS total_no_transactions,
MIN(transaction_date) AS first_date,
MAX(transaction_date) AS last_date
FROM credit_card_data
GROUP BY city
),
CTE2 AS
(
SELECT * FROM CTE1 WHERE total_no_transactions >=500
),
CTE3 AS
(
SELECT city, transaction_date,
ROW_NUMBER() OVER(PARTITION BY city ORDER BY transaction_date) AS row_num FROM credit_card_data
WHERE CITY IN (SELECT city FROM CTE2)
),
CTE4 AS
(
SELECT CTE2.city, CTE2.first_date,CTE2.last_date,CTE2.total_no_transactions,CTE3.transaction_date AS trans_date_500th
FROM CTE2
INNER JOIN CTE3
ON CTE2.city = CTE3.city
WHERE CTE3.row_num = 500
)
SELECT TOP 1 city, first_date, last_date, trans_date_500th,
DATEDIFF(DAY,first_date,trans_date_500th) AS no_days_till_500
FROM CTE4
ORDER BY no_days_till_500;




