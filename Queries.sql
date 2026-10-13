-- RFM Customer Segmentation | Dataset: Online Retail II (UCI)
CREATE DATABASE IF NOT EXISTS retail_db;
USE retail_db;

-- 1. Raw table (all text; converted during cleaning)
CREATE TABLE online_retail (
  Invoice VARCHAR(20), StockCode VARCHAR(20), Description TEXT,
  Quantity VARCHAR(20), InvoiceDate VARCHAR(30), Price VARCHAR(20),
  CustomerID VARCHAR(20), Country VARCHAR(60)
);

-- 2. Load the CSV (change the path to your MySQL secure_file_priv folder)
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/online_retail_II.csv'
INTO TABLE online_retail
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

-- 3. Clean: remove cancelled orders, missing customers, invalid quantity/price
CREATE TABLE clean_sales AS
SELECT Invoice,
       CAST(CAST(NULLIF(CustomerID,'') AS DECIMAL(10,1)) AS UNSIGNED) AS CustomerID,
       STR_TO_DATE(InvoiceDate, '%Y-%m-%d %H:%i:%s') AS InvoiceDate,
       CAST(Quantity AS SIGNED) AS Quantity,
       CAST(Price AS DECIMAL(10,2)) AS Price,
       CAST(Quantity AS SIGNED) * CAST(Price AS DECIMAL(10,2)) AS Revenue
FROM online_retail
WHERE CustomerID IS NOT NULL AND CustomerID <> ''
  AND Invoice NOT LIKE 'C%'
  AND CAST(Quantity AS SIGNED) > 0
  AND CAST(Price AS DECIMAL(10,2)) > 0;

-- 4. Recency, Frequency, Monetary per customer
CREATE TABLE rfm AS
SELECT CustomerID,
       DATEDIFF((SELECT MAX(InvoiceDate) + INTERVAL 1 DAY FROM clean_sales), MAX(InvoiceDate)) AS Recency,
       COUNT(DISTINCT Invoice) AS Frequency,
       ROUND(SUM(Revenue), 2) AS Monetary
FROM clean_sales
GROUP BY CustomerID;

-- 5. Score each metric 1-5
CREATE TABLE rfm_scored AS
SELECT *,
       NTILE(5) OVER (ORDER BY Recency DESC) AS R,
       NTILE(5) OVER (ORDER BY Frequency)    AS F,
       NTILE(5) OVER (ORDER BY Monetary)     AS M
FROM rfm;

-- 6. Segment customers
CREATE TABLE rfm_segments AS
SELECT *,
  CASE
    WHEN R >= 4 AND F >= 4 AND M >= 4 THEN 'Champions'
    WHEN R >= 3 AND F >= 3             THEN 'Loyal'
    WHEN R <= 2 AND F >= 3             THEN 'At Risk'
    WHEN R <= 2 AND F <= 2             THEN 'Lost'
    ELSE 'Potential'
  END AS Segment
FROM rfm_scored;

-- 7. Segment summary
SELECT Segment,
       COUNT(*) AS Customers,
       ROUND(100 * COUNT(*) / (SELECT COUNT(*) FROM rfm_segments), 1) AS Customer_Pct,
       ROUND(SUM(Monetary), 0) AS Revenue,
       ROUND(100 * SUM(Monetary) / (SELECT SUM(Monetary) FROM rfm_segments), 1) AS Revenue_Pct
FROM rfm_segments
GROUP BY Segment
ORDER BY Revenue DESC;