---------------------------------------AdventureWorks-Sales-and-Customer-Analysis-Project

---1  
-- Question: Annual Sales & Revenue Growth: Calculate the annual sales total and linear revenue for each year. Find the growth rate of linear revenue compared to the previous year.
SELECT YEAR(SO.OrderDate) AS 'YEAR' -- Extract the year from the order date
,SUM(IL.ExtendedPrice - IL.TaxAmount) AS 'IncomePerYear' -- Calculate the total income per year
,COUNT(DISTINCT MONTH(OrderDate)) AS 'NumberOfDistinctMonths' -- Count the number of distinct months in the order date
,SUM(IL.ExtendedPrice - IL.TaxAmount)/COUNT(DISTINCT MONTH(OrderDate)) * 12 AS 'YearlyLinearIncome' -- Calculate the yearly linear income
,FORMAT(((SUM(IL.ExtendedPrice - IL.TaxAmount)/COUNT(DISTINCT MONTH(OrderDate)) * 12 - LAG(SUM(IL.ExtendedPrice - IL.TaxAmount)/COUNT(DISTINCT MONTH(OrderDate)) * 12) OVER (ORDER BY YEAR(OrderDate))) * 100.0) 
        / NULLIF(LAG(SUM(IL.ExtendedPrice - IL.TaxAmount)/COUNT(DISTINCT MONTH(OrderDate)) * 12) OVER (ORDER BY YEAR(OrderDate)), 0),'N2') AS 'GrowthRate' -- Calculate the growth rate of linear income
FROM SALES.Orders SO JOIN SALES.Invoices SI
                     ON SO.OrderID = SI.OrderID -- Join Orders and Invoices tables
                     JOIN Sales.InvoiceLines IL
                     ON SI.InvoiceID = IL.InvoiceID -- Join Invoices and InvoiceLines tables
GROUP BY YEAR(SO.OrderDate) -- Group by year
ORDER BY YEAR(SO.OrderDate) -- Order by year

-------------------------------------------------------------------------

---2 
-- Question: Top 5 Customers by Revenue: List the top 5 customers by net revenue for each quarter of the year.
GO
WITH TBL
AS(
SELECT  
 YEAR(SO.OrderDate) AS 'TheYear' -- Extract the year from the order date
,DATEPART(QQ,SO.OrderDate)  AS 'TheQuarter' -- Extract the quarter from the order date
,C.CustomerName -- Select the customer name
,SUM(IL.Quantity * IL.UnitPrice)   AS 'IncomePerYear' -- Calculate the total income per year
,DENSE_RANK() OVER(PARTITION BY YEAR(SO.OrderDate), DATEPART(QQ,SO.OrderDate) ORDER BY SUM(IL.Quantity * IL.UnitPrice )DESC) AS 'DNR' -- Rank customers by income per quarter
FROM SALES.Customers C JOIN Sales.Orders SO
                       ON C.CustomerID = SO.CustomerID -- Join Customers and Orders tables
                       JOIN SALES.Invoices SI
                       ON SO.OrderID = SI.OrderID -- Join Orders and Invoices tables
                       JOIN Sales.InvoiceLines IL
                       ON SI.InvoiceID = IL.InvoiceID -- Join Invoices and InvoiceLines tables
GROUP BY C.CustomerName,DATEPART(QQ,SO.OrderDate),YEAR(SO.OrderDate) -- Group by customer name, quarter, and year
)
SELECT TheYear, TheQuarter, CustomerName, IncomePerYear, DNR -- Select the year, quarter, customer name, income per year, and rank
FROM TBL
WHERE DNR <= 5 -- Filter to show only the top 5 customers

-------------------------------------------------------------------------

---3 
-- Question: Top Products by Profit: Identify the products with the highest total profit, based on sales, and rank them.
SELECT TOP 10 SI.StockItemID, SI.StockItemName -- Select the top 10 stock items by ID and name
,SUM(INL.ExtendedPrice - INL.TaxAmount) AS TotalProfit -- Calculate the total profit for each stock item
FROM Warehouse.StockItems SI JOIN SALES.InvoiceLines INL
                              ON SI.StockItemID = INL.StockItemID -- Join StockItems and InvoiceLines tables
GROUP BY SI.StockItemID, SI.StockItemName -- Group by stock item ID and name
ORDER BY SUM(INL.ExtendedPrice - INL.TaxAmount) DESC -- Order by total profit in descending order

-------------------------------------------------------------------------

---4 
-- Question: Stock Items Profit: List valid stock items and calculate their nominal profit (retail price - unit price), ranked by nominal profit.
GO
WITH T
AS(
SELECT SI.StockItemID, SI.StockItemName,INL.UnitPrice, SI.RecommendedRetailPrice -- Select stock item ID, name, unit price, and recommended retail price
,SI.RecommendedRetailPrice - INL.UnitPrice AS Nominal -- Calculate the nominal profit
,SI.ValidFrom, SI.ValidTo -- Select the valid from and to dates
,ROW_NUMBER()OVER(PARTITION BY SI.StockItemID ORDER BY SI.RecommendedRetailPrice - INL.UnitPrice ) AS DNR -- Rank stock items by nominal profit
FROM Warehouse.StockItems SI JOIN SALES.InvoiceLines INL
                              ON SI.StockItemID = INL.StockItemID -- Join StockItems and InvoiceLines tables
WHERE GETDATE() BETWEEN SI.ValidFrom AND SI.ValidTo -- Filter to show only valid stock items
)
SELECT ROW_NUMBER() OVER(ORDER BY Nominal DESC) AS RN -- Rank the results by nominal profit
,*
FROM T
WHERE DNR = 1 -- Filter to show only the top-ranked stock items
ORDER BY Nominal DESC -- Order by nominal profit in descending order

-------------------------------------------------------------------------

---5 
-- Question: Supplier Product List: Show a list of products for each supplier, separated by commas.
GO
SELECT S.SupplierName, STRING_AGG(P.ProductName, ', ') AS ProductList -- Select supplier name and list of products
FROM Purchasing.Suppliers S
JOIN Production.Products P ON S.SupplierID = P.SupplierID -- Join Suppliers and Products tables
GROUP BY S.SupplierName -- Group by supplier name

-------------------------------------------------------------------------

---6 
-- Question: Top Customers by Spend: List the top 5 customers by total spend, including geographical details.
GO
WITH TBL
AS(
SELECT  
 C.CustomerName -- Select the customer name
,C.City -- Select the city
,C.StateProvince -- Select the state/province
,C.Country -- Select the country
,SUM(IL.Quantity * IL.UnitPrice) AS 'TotalSpend' -- Calculate the total spend
,DENSE_RANK() OVER(ORDER BY SUM(IL.Quantity * IL.UnitPrice) DESC) AS 'DNR' -- Rank customers by total spend
FROM SALES.Customers C JOIN Sales.Orders SO
                       ON C.CustomerID = SO.CustomerID -- Join Customers and Orders tables
                       JOIN SALES.Invoices SI
                       ON SO.OrderID = SI.OrderID -- Join Orders and Invoices tables
                       JOIN Sales.InvoiceLines IL
                       ON SI.InvoiceID = IL.InvoiceID -- Join Invoices and InvoiceLines tables
GROUP BY C.CustomerName, C.City, C.StateProvince, C.Country -- Group by customer name, city, state/province, and country
)
SELECT CustomerName, City, StateProvince, Country, TotalSpend, DNR -- Select the customer name, city, state/province, country, total spend, and rank
FROM TBL
WHERE DNR <= 5 -- Filter to show only the top 5 customers

-------------------------------------------------------------------------
        
---7 
-- Question: Monthly Product Sales: Display the total sales per product each month, with an accumulated total for the year.
GO
SELECT YEAR(SO.OrderDate) AS 'YEAR' -- Extract the year from the order date
,MONTH(SO.OrderDate) AS 'MONTH' -- Extract the month from the order date
,P.ProductName -- Select the product name
,SUM(IL.Quantity * IL.UnitPrice) AS 'MonthlySales' -- Calculate the total sales per month
,SUM(SUM(IL.Quantity * IL.UnitPrice)) OVER(PARTITION BY P.ProductName ORDER BY YEAR(SO.OrderDate), MONTH(SO.OrderDate)) AS 'AccumulatedSales' -- Calculate the accumulated total sales for the year
FROM SALES.Orders SO JOIN SALES.Invoices SI
                     ON SO.OrderID = SI.OrderID -- Join Orders and Invoices tables
                     JOIN Sales.InvoiceLines IL
                     ON SI.InvoiceID = IL.InvoiceID -- Join Invoices and InvoiceLines tables
                     JOIN Production.Products P
                     ON IL.ProductID = P.ProductID -- Join InvoiceLines and Products tables
GROUP BY YEAR(SO.OrderDate), MONTH(SO.OrderDate), P.ProductName -- Group by year, month, and product name
ORDER BY YEAR(SO.OrderDate), MONTH(SO.OrderDate), P.ProductName -- Order by year, month, and product name

-------------------------------------------------------------------------
        
---8 
-- Question: Monthly Orders: Show the number of orders placed each month of the year.
GO
SELECT YEAR(OrderDate) AS 'YEAR' -- Extract the year from the order date
,MONTH(OrderDate) AS 'MONTH' -- Extract the month from the order date
,COUNT(OrderID) AS 'TotalOrders' -- Count the number of orders
FROM SALES.Orders
GROUP BY YEAR(OrderDate), MONTH(OrderDate) -- Group by year and month
ORDER BY YEAR(OrderDate), MONTH(OrderDate) -- Order by year and month

-------------------------------------------------------------------------

---9 
-- Question: Churn Risk Customers: Identify customers at risk of churn based on order patterns (last order time greater than twice the average order time).
GO
WITH AvgOrderTime AS (
    SELECT CustomerID, AVG(DATEDIFF(day, LAG(OrderDate) OVER (PARTITION BY CustomerID ORDER BY OrderDate), OrderDate)) * 2 AS AvgOrderTime -- Calculate the average order time and multiply by 2
    FROM SALES.Orders
    GROUP BY CustomerID -- Group by customer ID
),
LastOrderTime AS (
    SELECT CustomerID, MAX(OrderDate) AS LastOrderDate -- Select the last order date for each customer
    FROM SALES.Orders
    GROUP BY CustomerID -- Group by customer ID
)
SELECT C.CustomerName, AOT.AvgOrderTime, DATEDIFF(day, LOT.LastOrderDate, GETDATE()) AS DaysSinceLastOrder -- Select the customer name, average order time, and days since last order
FROM AvgOrderTime AOT
JOIN LastOrderTime LOT ON AOT.CustomerID = LOT.CustomerID -- Join AvgOrderTime and LastOrderTime tables
JOIN SALES.Customers C ON AOT.CustomerID = C.CustomerID -- Join AvgOrderTime and Customers tables
WHERE DATEDIFF(day, LOT.LastOrderDate, GETDATE()) > AOT.AvgOrderTime -- Filter to show customers at risk of churn

-------------------------------------------------------------------------

