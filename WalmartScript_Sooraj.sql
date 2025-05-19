select * from walmart;
-- Coverting Date and Time columns to Datetime 

ALTER TABLE walmart
Add column Date_Time Datetime; 
SET SQL_SAFE_UPDATES = 0;
Update walmart
Set Date_Time = str_to_date(CONCAT(Date,' ', Time), '%d-%m-%Y %H:%i:%s');

-- Task 1: Identify the Top Branch by Sales Growth Rate. 

-- Step 1: Extarct the year and the month form Date_time column.
-- Step 2: Sum total salaes(Total) for each branch per month using Groupby.

WITH MonthlySales as (
	Select Branch, DATE_FORMAT(Date_Time, '%Y-%m') as YearMonth, sum(Total) as MonthlyTotal from walmart group by Branch, YearMonth),
    
-- Step 3: Calculate month-month growth for each branch. 
SalesGrowth AS (
  SELECT 
    a.Branch,
    a.YearMonth,
    a.MonthlyTotal,
    a.MonthlyTotal - COALESCE(b.MonthlyTotal, 0) AS Growth
  FROM MonthlySales a
  LEFT JOIN MonthlySales b
    ON a.Branch = b.Branch
    AND STR_TO_DATE(a.YearMonth, '%Y-%m') = DATE_ADD(STR_TO_DATE(b.YearMonth, '%Y-%m'), INTERVAL 1 MONTH)
)
-- Step 4: Find the branch with the highest overall growth trend. 
Select Branch, Sum(Growth) as TotalGrowth from SalesGrowth Group by Branch Order by TotalGrowth DESC Limit 3;

-- Task 2: Finding the Most Porfitable Product Line for each branch.

With ProductLineProfit as (select branch, `Product Line`, SUM(`gross income`) as TotalProfit from walmart group by branch, `Product Line`),

ProfitRank as (select *, RANK() OVER(PARTITION BY BRANCH ORDER BY TotalProfit DESC) as BranchRank From ProductLineProfit)

select Branch, `Product Line`, Round(TotalProfit, 2) as TotalProfit from ProfitRank where BranchRank = 1;

-- Task 3: Analyzing Customer Segmentation Based in Spending
With CustomerAverageSpending as ( 
	Select `Customer ID`, `Customer Type`, Round(AVG(Total), 2) as AverageSpending from walmart group by `Customer ID`, `Customer Type`
),

-- Instead if applying fixed cases we can apply dynamic tiering using NTILE(3). This adapt to the data distribution. 

CustomerSegment as (
	Select *, NTILE(3) OVER(Order by AverageSpending DESC) as SpendTier from CustomerAverageSpending)

Select `Customer ID`, `Customer type`, AverageSpending, 
case
	when SpendTier = 1 Then 'High'
    when SpendTier = 2 Then 'Medium'
    Else 'Low'
END AS SpenderLevel
From CustomerSegment;

-- Task 4: Detecting Anomalies in Sales Transactions
With ProductLineStat as ( 
	select `Product Line`, Avg(Total) as AverageTotal, STDDEV(Total) as StdTotal
from walmart
group by `Product Line`),
-- Totals there are = μ - 2σ unusually low OR = μ + 2σ unsually high
Anomalies as (
	Select wm.*, pls.AverageTotal, pls.StdTotal from walmart wm join ProductLineStat pls on wm.`Product Line` = pls.`Product Line`
    where
    wm.Total > pls.AverageTotal + 2* pls.StdTotal  
    or 
    wm.Total < pls.AverageTotal - 2 * pls.StdTotal  
)

select `Invoice ID`, `Product line`, Total, Round(AverageTotal,2) as ProductLineAvgSales, round(StdTotal) as std,
CASE
	when Total > AverageTotal + 2 * StdTotal then 'High Anomaly'
    when Total < AverageTotal - 2 * StdTotal then 'Low Anomaly'
End as AnomalyType
From Anomalies;

-- this indicates a right skewed distribution

-- Task 5: Most Popular Payment Method by City
with PayCount As (
	Select City, Payment, count(*) as PaymentDone
from walmart
group by City, Payment),

PayRank AS (
	Select *, Rank() OVER(Partition by city order by PaymentDone DESC) as CityRank
From PayCount)

Select City, Payment as `Popular Payment Method`, PaymentDone as `Payments Made` from PayRank where CityRank = 1;

-- Task 6: Monthly Sales Distribution by Gender

SELECT 
  DATE_FORMAT(Date_Time, '%m-%Y') AS SaleMonth,
  Gender,
  Round(SUM(Total),2) AS MonthlySales
FROM walmart
GROUP BY SaleMonth, Gender
ORDER BY SaleMonth, Gender;

-- Task 7: Best Product Line by Customer Type
with product_pref as ( 
select `Customer type`, `Product Line`, Count(*) as PurchaseCount from walmart group by `Customer type`, `Product line`),

RankedProductLine As( 
	select *, Dense_Rank() Over(Partition by `Customer type` Order by PurchaseCount DESC) as TypeRank from product_pref)
    
Select `Product line` as `Most preferred product line`, `Customer Type`, purchaseCount from RankedProductLine where TypeRank = 1;

-- Task 8: Identifying Repeat Customer
DELIMITER //

CREATE PROCEDURE FindRepeatCustomersInWindow(IN start_date DATE, IN days_interval INT)
BEGIN
  DECLARE end_date DATE;
  SET end_date = DATE_ADD(start_date, INTERVAL days_interval DAY);
  SELECT 
    `Customer ID`, COUNT(*) AS RepeatCount, start_date AS StartDate, end_date AS EndDate
  FROM walmart
  WHERE DATE(Date_Time) BETWEEN start_date AND end_date
  GROUP BY `Customer ID`
  HAVING COUNT(*) > 1
  ORDER BY RepeatCount DESC;
END //

DELIMITER ;

CALL FindRepeatCustomersInWindow('2019-01-01', 30);

-- Task 9: Find Top 5 Customer by Sales Volume 

SELECT *
FROM (
  SELECT 
	DENSE_RANK() OVER (ORDER BY SUM(Total) DESC) AS PurchaseRank,
    `Customer ID`,
    ROUND(SUM(Total), 2) AS TotalPurchaseAmt
  FROM walmart
  GROUP BY `Customer ID`
) ranked
WHERE PurchaseRank <= 5;


-- Task 10: Analyzing Sales Trend by Day of the Week
SELECT 
    DAYNAME(Date_time) AS `Day of the Week`,
    ROUND(SUM(Total), 2) AS TotalSales
FROM
    walmart
GROUP BY `Day of the Week`
ORDER BY `Day of the Week`;







