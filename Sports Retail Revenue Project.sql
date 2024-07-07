CREATE DATABASE Project
GO

USE Project
GO


-- Step1: Gain a deep understanding of the data
SELECT TOP 5 * FROM dbo.finance
SELECT TOP 5 * FROM dbo.info
SELECT TOP 5 * FROM dbo.brands
SELECT TOP 5 * FROM dbo.reviews
SELECT TOP 5 * FROM dbo.traffic


-- Step2: Changing datatypes (this also can be done when importing data)

-- Column Finance
ALTER TABLE dbo.finance
ALTER COLUMN listing_price FLOAT
GO
ALTER TABLE dbo.finance
ALTER COLUMN sale_price FLOAT
GO
ALTER TABLE dbo.finance
ALTER COLUMN discount FLOAT
GO
ALTER TABLE dbo.finance
ALTER COLUMN revenue FLOAT
GO

-- Column reviews
ALTER TABLE dbo.reviews
ALTER COLUMN rating FLOAT
GO
ALTER TABLE dbo.reviews
ALTER COLUMN reviews FLOAT
GO

-- Column traffic
ALTER TABLE dbo.traffic
ALTER COLUMN last_visited DATETIME
GO

-- Step 3: Checking for missing values

-- Finance Table
SELECT * 
FROM dbo.finance
WHERE listing_price = 0 OR
	  sale_price = 0  OR
	  discount = 0  OR
	  revenue = 0 

-- how manu null values in all colmns together
SELECT COUNT(*) AS NULLCOUNT
FROM dbo.finance
WHERE listing_price = 0 AND
	  sale_price = 0  AND
	  discount = 0  AND
	  revenue = 0
	  
-- Brands Table
SELECT *
FROM dbo.brands
WHERE LEN(ISNULL(brand, '')) = 0

-- how many null values
SELECT COUNT(*) AS NULLCOUNT
FROM dbo.brands
WHERE LEN(ISNULL(brand, '')) = 0

-- Info Table
SELECT *
FROM dbo.info
WHERE LEN(ISNULL(product_name, '')) = 0 OR LEN(ISNULL(description, '')) = 0

-- How many are null in both columns
SELECT COUNT(*) AS NULLCOUNT
FROM dbo.info
WHERE LEN(ISNULL(product_name, '')) = 0 AND LEN(ISNULL(description, '')) = 0

-- Reviews Table
SELECT * 
FROM dbo.reviews
WHERE rating  = 0 OR reviews = 0

-- How many are null in both columns
SELECT COUNT (*) NULLCOUNT
FROM dbo.reviews
WHERE rating  = 0 AND reviews = 0


-- Before proceeding with the removal or computation of NULL values, let's dive deeper into the analysis

-- This are the product ids that have null values in all of these tables
SELECT * FROM dbo.finance AS f
JOIN dbo.brands AS b ON b.product_id = f.product_id
JOIN dbo.info AS i ON i.product_id = f.product_id
JOIN dbo.reviews AS r ON r.product_id = f.product_id
JOIN dbo.traffic AS t ON t.product_id = f.product_id
WHERE listing_price = 0
  AND sale_price = 0
  AND discount = 0
  AND LEN(ISNULL(product_name, '')) = 0
  AND LEN(ISNULL(description, '')) = 0
  AND LEN(ISNULL(brand, '')) = 0
  AND rating = 0 AND reviews = 0

-- I decided to drop all of these rows in all columns
SELECT f.product_id AS product_id INTO #ProductIds
FROM dbo.finance AS f
JOIN dbo.brands AS b ON b.product_id = f.product_id
JOIN dbo.info AS i ON i.product_id = f.product_id
JOIN dbo.reviews AS r ON r.product_id = f.product_id
JOIN dbo.traffic AS t ON t.product_id = f.product_id
WHERE listing_price = 0
  AND sale_price = 0
  AND discount = 0
  AND LEN(ISNULL(product_name, '')) = 0
  AND LEN(ISNULL(description, '')) = 0
  AND LEN(ISNULL(brand, '')) = 0
  AND rating = 0 AND reviews = 0
GO

DELETE FROM dbo.finance
WHERE product_id IN (SELECT product_id FROM #ProductIds)

DELETE FROM dbo.brands
WHERE product_id IN (SELECT product_id FROM #ProductIds)

DELETE FROM dbo.info
WHERE product_id IN (SELECT product_id FROM #ProductIds)

DELETE FROM dbo.reviews
WHERE product_id IN (SELECT product_id FROM #ProductIds)

DELETE FROM dbo.traffic
WHERE product_id IN (SELECT product_id FROM #ProductIds)

-- Drop the temporary table
DROP TABLE #ProductIds


-- Let's continue analizing null values that are left

--**FINANCE TABLE** 
-- sale price = listing price * discount, listing price is the initial price, revenue is (quantity sold * price unit) - discounts
UPDATE dbo.finance
SET listing_price = sale_price
WHERE listing_price = 0 AND discount = 0

-- here we will update the discount
UPDATE dbo.finance
SET discount = ROUND(sale_price / listing_price,2)
WHERE discount = 0 AND (listing_price != sale_price)

-- for table revenue where revenue = 0 i decided to populate with average value (or in other case i could delete them because there are 220/3120 rows where revenue = 0)
UPDATE dbo.finance
SET revenue = ROUND((select AVG(revenue) from dbo.finance),2)
WHERE revenue = 0

--**BRANDS TABLE**
-- DELETE all this rows (59/3179)
DELETE FROM dbo.brands
WHERE LEN(ISNULL(brand, '')) = 0

-- **INFO TABLE**
DELETE FROM dbo.info
WHERE LEN(ISNULL(product_name, '')) = 0 AND LEN(ISNULL(description, '')) = 0

-- **REVIEWS TABLE** 
--i think there is no need for deleting, there are always products that don't have reviews or ratings
SELECT * FROM dbo.reviews
WHERE rating  = 0 AND reviews = 0

-- Analysis Query

-- Calculate total sales revenue over a year for each brand
SELECT DISTINCT b.brand, year(t.last_visited) AS year,
SUM(revenue) OVER(PARTITION BY year(t.last_visited),b.brand) AS TotalSalesRevenuePerYear
FROM dbo.finance AS f
JOIN dbo.traffic AS t ON t.product_id = f.product_id
JOIN dbo.brands AS b ON b.product_id = f.product_id
ORDER BY year

-- Calculate monthly total sales revenue for each brand in all of the year
SELECT b.brand, month(last_visited) AS month,
	   SUM(f.revenue) AS SalesRevenue
FROM dbo.finance AS f
JOIN dbo.brands AS b ON b.product_id = f.product_id
JOIN dbo.traffic AS t ON t.product_id = f.product_id
GROUP BY b.brand,month(last_visited)
ORDER BY month

-- Calculate the average discount by brand
SELECT b.brand, ROUND(AVG(discount),3) AS AverageDiscount
FROM dbo.finance AS f
JOIN dbo.brands AS b ON b.product_id = f.product_id
GROUP BY b.brand

-- Find and list the top 10 products ranked by their highest revenue
SELECT TOP 10 i.product_name, 
	   SUM(revenue) as TotalRevenue
FROM dbo.finance AS f
JOIN dbo.info AS i ON i.product_id = f.product_id
GROUP BY i.product_name
ORDER BY TotalRevenue DESC


-- Find Average Revenue by brand
SELECT b.brand, ROUND(AVG(revenue),3) AS AverageRevenue 
FROM dbo.finance AS f
JOIN dbo.brands AS b ON b.product_id = f.product_id
GROUP BY b.brand

-- Identify the top 5 most visited products
SELECT TOP 5 i.product_name, COUNT(t.product_id) AS Visits
FROM dbo.traffic AS t
JOIN dbo.info AS i ON i.product_id = t.product_id
GROUP BY i.product_name
ORDER BY Visits DESC

-- List 2 products that have smallest revenue in April 2020 by brand
; WITH CTE AS (
SELECT i.product_name as product, 
       b.brand as brand, 
	   t.last_visited,
	   SUM(revenue) AS TotalRevenue,
	   ROW_NUMBER() OVER(PARTITION BY b.brand ORDER BY SUM(revenue) ASC) AS RN
FROM dbo.finance AS f
JOIN dbo.brands AS b ON b.product_id = f.product_id
JOIN dbo.traffic AS t ON t.product_id = f.product_id
JOIN dbo.info AS i ON i.product_id = f.product_id
WHERE MONTH(t.last_visited) = 4 AND YEAR(t.last_visited) = 2020
GROUP BY i.product_name, b.brand, t.last_visited
)
SELECT product,brand,TotalRevenue
FROM CTE
WHERE RN <= 2

-- Find Average ratings and reviews by product description length
SELECT DISTINCT LEN(description) AS DescriptionLength,
	   ROUND(AVG(rating) OVER(ORDER BY LEN(description)),2) AS AverageRating,
	   ROUND(AVG(reviews) OVER(ORDER BY LEN(description)),2) AS AverageReview
FROM dbo.reviews AS r
JOIN dbo.info AS i ON i.product_id = r.product_id


-- Calculate the Number of Products per Brand
SELECT brand, COUNT(*) AS NumberOfProducts 
FROM dbo.brands AS b
GROUP BY brand

-- Find top 5 highest rated products by brand
; WITH CTE2 AS (
SELECT i.product_name, rating, b.brand,
ROW_NUMBER() OVER (PARTITION BY b.brand ORDER BY rating DESC) AS rn
FROM dbo.reviews AS r
JOIN dbo.info AS i ON i.product_id = r.product_id
JOIN dbo.brands AS b ON b.product_id = r.product_id
)
SELECT product_name,rating,brand 
FROM CTE2
WHERE rn <= 5


-- Write a function that for product name as input will return ratings and reviews
CREATE OR ALTER FUNCTION dbo.fn_ProductReview (@ProductName varchar(1000))
RETURNS @Results TABLE (Rating float, Review float)
AS
BEGIN

INSERT INTO @Results(Rating,Review)
SELECT SUM(r.rating) AS Rating, SUM(r.reviews) AS Review
FROM dbo.reviews AS r
JOIN dbo.info AS i ON i.product_id = r.product_id
WHERE i.product_name = @ProductName

RETURN 
END

-- Testing the function for product Nike Air Max 90 and Nike Air Max 200
SELECT * FROM dbo.fn_ProductReview('Nike Air Max 90')
SELECT * FROM dbo.fn_ProductReview('Nike Air Max 200')



