use olist_ecommerce;

-- 1) SALES ANALYSIS
SELECT COUNT(order_id) AS total_orders FROM orders;

SELECT ROUND(SUM(payment_value), 2) AS total_revenue FROM order_payments;

SELECT order_status, COUNT(order_id) AS total_orders FROM orders
GROUP BY order_status
ORDER BY total_orders DESC;

SELECT MONTHNAME(STR_TO_DATE(order_purchase_timestamp,'%d-%m-%Y %H:%i')) AS month_name, COUNT(order_id) AS total_orders FROM orders
GROUP BY month_name
ORDER BY MONTHNAME(STR_TO_DATE(order_purchase_timestamp,'%d-%m-%Y %H:%i'));

SELECT monthname(STR_TO_DATE(o.order_purchase_timestamp,'%d-%m-%Y %H:%i')) AS month, ROUND(SUM(p.payment_value),2) AS revenue FROM orders o
JOIN order_payments p ON o.order_id = p.order_id
GROUP BY month ORDER BY month;

SELECT YEAR(STR_TO_DATE(o.order_purchase_timestamp,'%d-%m-%Y %H:%i')) AS year, ROUND(SUM(p.payment_value),2) AS total_sales FROM orders o
JOIN order_payments p ON o.order_id = p.order_id
GROUP BY year ORDER BY year;

SELECT order_id, ROUND(SUM(payment_value),2) AS total_payment FROM order_payments
GROUP BY order_id
ORDER BY total_payment DESC LIMIT 10;

WITH monthly_revenue AS 
(SELECT DATE_FORMAT(STR_TO_DATE(o.order_purchase_timestamp,'%d-%m-%Y %H:%i:%s'),'%Y-%m') AS month, ROUND(SUM(p.payment_value),2) AS revenue FROM orders o
JOIN order_payments p ON o.order_id = p.order_id
GROUP BY month)
SELECT month, revenue, LAG(revenue) OVER(ORDER BY month) AS previous_month_revenue,
ROUND(((revenue - LAG(revenue) OVER(ORDER BY month))/LAG(revenue) OVER(ORDER BY month)) * 100, 2) AS mom_growth_percentage
FROM monthly_revenue;

WITH monthly_revenue AS 
(SELECT monthname(STR_TO_DATE(o.order_purchase_timestamp,'%d-%m-%Y %H:%i')) AS month, ROUND(SUM(p.payment_value),2) AS revenue FROM orders o
JOIN order_payments p ON o.order_id = p.order_id
GROUP BY month)
SELECT month, revenue,
ROUND((revenue/SUM(revenue) OVER()) * 100,2) AS revenue_contribution_percentage
FROM monthly_revenue
ORDER BY month;

SELECT 
 CASE
	WHEN DAYNAME(STR_TO_DATE(o.order_purchase_timestamp,'%d-%m-%Y %H:%i')) IN ('Saturday', 'Sunday')
      THEN 'Weekend'
	  ELSE 'Weekday'
    END AS day_type,
ROUND(SUM(p.payment_value),2) AS total_sales FROM orders o
JOIN order_payments p ON o.order_id = p.order_id
GROUP BY day_type;

SELECT payment_type, COUNT(order_id) AS total_orders, ROUND((COUNT(order_id)/SUM(COUNT(order_id)) OVER()) * 100,2) AS percentage_distribution FROM order_payments
GROUP BY payment_type ORDER BY total_orders DESC;

WITH monthly_orders AS 
(SELECT monthname(STR_TO_DATE(order_purchase_timestamp,'%d-%m-%Y %H:%i')) AS month, COUNT(order_id) AS total_orders,
SUM(
   CASE
	 WHEN order_status = 'canceled'
		THEN 1
		ELSE 0
	 END) AS canceled_orders
FROM orders
GROUP BY month)
SELECT month, total_orders, canceled_orders, ROUND((canceled_orders/ total_orders) * 100,2) AS cancellation_rate
FROM monthly_orders
ORDER BY month;

WITH monthly_revenue AS 
(SELECT monthname(STR_TO_DATE(o.order_purchase_timestamp,'%d-%m-%Y %H:%i')) AS month,ROUND(SUM(p.payment_value),2) AS revenue FROM orders o
JOIN order_payments p ON o.order_id = p.order_id
GROUP BY month)
SELECT month,revenue,RANK() OVER(ORDER BY revenue DESC) AS revenue_rank
FROM monthly_revenue;

WITH monthly_revenue AS 
(SELECT monthname(STR_TO_DATE(o.order_purchase_timestamp,'%d-%m-%Y %H:%i')) AS month,ROUND(SUM(p.payment_value),2) AS revenue FROM orders o
JOIN order_payments p ON o.order_id = p.order_id
GROUP BY month),
revenue_change AS 
(SELECT month,revenue,LAG(revenue) OVER(ORDER BY month) AS previous_revenue FROM monthly_revenue)
SELECT month,revenue,previous_revenue,ROUND(((revenue - previous_revenue)/previous_revenue) * 100,2) AS revenue_growth_percentage
FROM revenue_change
where((revenue - previous_revenue)/previous_revenue) * 100 < -20;


-- 2) CUSTOMER ANALYSIS
SELECT COUNT(DISTINCT customer_unique_id) AS total_unique_customers FROM customers;

SELECT customer_state,COUNT(DISTINCT customer_unique_id) AS total_customers FROM customers
GROUP BY customer_state ORDER BY total_customers DESC;

SELECT c.customer_unique_id,ROUND(SUM(p.payment_value),2) AS total_spending FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_payments p ON o.order_id = p.order_id
GROUP BY c.customer_unique_id ORDER BY total_spending DESC LIMIT 10;

SELECT c.customer_unique_id,COUNT(o.order_id) AS total_orders FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_unique_id ORDER BY total_orders DESC LIMIT 10;

SELECT c.customer_unique_id,MIN(STR_TO_DATE(o.order_purchase_timestamp,'%Y-%m-%d %H:%i:%s')) AS first_purchase,MAX(STR_TO_DATE(o.order_purchase_timestamp,'%Y-%m-%d %H:%i:%s')) AS last_purchase FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_unique_id;

SELECT c.customer_unique_id,COUNT(o.order_id) AS total_orders FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_unique_id HAVING COUNT(o.order_id) = 1;

WITH customer_orders AS 
(SELECT c.customer_unique_id,COUNT(o.order_id) AS total_orders FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_unique_id)
SELECT ROUND((COUNT(
                CASE
                    WHEN total_orders > 1
                    THEN 1
                END)/COUNT(*)) * 100,2) AS repeat_customer_rate
FROM customer_orders;

WITH customer_purchases AS 
(SELECT c.customer_unique_id,STR_TO_DATE(o.order_purchase_timestamp,'%d-%m-%Y %H:%i') AS purchase_date,
LAG(STR_TO_DATE(o.order_purchase_timestamp,'%d-%m-%Y %H:%i')) OVER(PARTITION BY c.customer_unique_id ORDER BY STR_TO_DATE(o.order_purchase_timestamp,'%d-%m-%Y %H:%i')) AS previous_purchase
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id)
SELECT ROUND(AVG(DATEDIFF(purchase_date,previous_purchase)),2) AS avg_days_between_purchases
FROM customer_purchases
WHERE previous_purchase IS NOT NULL;

SELECT c.customer_city,ROUND(SUM(p.payment_value),2) AS total_revenue FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_payments p ON o.order_id = p.order_id
GROUP BY c.customer_city ORDER BY total_revenue DESC LIMIT 10;

WITH customer_spending AS
(SELECT c.customer_unique_id,SUM(p.payment_value) AS total_spending FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_payments p ON o.order_id = p.order_id
GROUP BY c.customer_unique_id)
SELECT customer_unique_id,total_spending,
CASE
   WHEN total_spending < 100
   THEN 'Low Spender'
   WHEN total_spending BETWEEN 100 AND 500
   THEN 'Medium Spender'
   ELSE 'High Spender'
END AS customer_segment
FROM customer_spending;

SELECT c.customer_unique_id,COUNT(o.order_id) AS total_orders FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_unique_id HAVING COUNT(o.order_id) = 1;

WITH customer_revenue AS 
(SELECT c.customer_unique_id,SUM(p.payment_value) AS revenue FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_payments p ON o.order_id = p.order_id
GROUP BY c.customer_unique_id),
ranked_customers AS 
(SELECT customer_unique_id,revenue,SUM(revenue) OVER(ORDER BY revenue DESC) AS cumulative_revenue,SUM(revenue) OVER() AS total_revenue FROM customer_revenue)
SELECT customer_unique_id,revenue FROM ranked_customers
WHERE cumulative_revenue <= total_revenue * 0.20;

SELECT c.customer_unique_id,ROUND(SUM(p.payment_value),2) AS customer_lifetime_value FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_payments p ON o.order_id = p.order_id
GROUP BY c.customer_unique_id ORDER BY customer_lifetime_value DESC;

WITH customer_rfm AS 
(SELECT c.customer_unique_id,MAX(STR_TO_DATE(o.order_purchase_timestamp,'%Y-%m-%d %H:%i:%s')) AS last_purchase_date,COUNT(o.order_id) AS frequency,ROUND(SUM(p.payment_value),2) AS monetary FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_payments p ON o.order_id = p.order_id
GROUP BY c.customer_unique_id)
SELECT customer_unique_id,DATEDIFF((SELECT MAX(STR_TO_DATE(order_purchase_timestamp,'%Y-%m-%d %H:%i:%s')) FROM orders),last_purchase_date) AS recency,frequency,monetary
FROM customer_rfm;

WITH customer_rfm AS 
(SELECT c.customer_unique_id,DATEDIFF((SELECT MAX(STR_TO_DATE(order_purchase_timestamp,'%Y-%m-%d %H:%i:%s'))FROM orders),MAX(STR_TO_DATE(o.order_purchase_timestamp,'%Y-%m-%d %H:%i:%s'))) AS recency,COUNT(o.order_id) AS frequency,SUM(p.payment_value) AS monetary
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_payments p ON o.order_id = p.order_id
GROUP BY c.customer_unique_id)
SELECT customer_unique_id,recency,frequency,monetary,
CASE
   WHEN recency > 180 AND frequency = 1
   THEN 'High Churn Risk'
   WHEN recency > 90
   THEN 'Medium Churn Risk'
   ELSE 'Low Churn Risk'
END AS churn_risk
FROM customer_rfm;


-- 3) PRODUCT ANALYSIS
SELECT COUNT(product_id) AS total_products FROM products;

SELECT DISTINCT product_category_name FROM products
ORDER BY product_category_name;

SELECT product_id,COUNT(order_id) AS total_sales FROM order_items
GROUP BY product_id ORDER BY total_sales DESC LIMIT 10;

SELECT p.product_category_name,COUNT(oi.order_id) AS total_sales FROM products p
JOIN order_items oi ON p.product_id = oi.product_id
GROUP BY p.product_category_name ORDER BY total_sales DESC LIMIT 10;

SELECT product_id,price FROM order_items
ORDER BY price DESC LIMIT 10;

SELECT ROUND(AVG(price),2) AS average_product_price
FROM order_items;

SELECT product_category_name,COUNT(product_id) AS total_products FROM products
GROUP BY product_category_name ORDER BY total_products DESC;

SELECT p.product_category_name,ROUND(SUM(op.payment_value),2) AS total_revenue FROM products p
JOIN order_items oi ON p.product_id = oi.product_id
JOIN order_payments op ON oi.order_id = op.order_id
GROUP BY p.product_category_name ORDER BY total_revenue DESC;

SELECT p.product_category_name,ROUND(AVG(r.review_score),2) AS avg_rating FROM products p
JOIN order_items oi ON p.product_id = oi.product_id
JOIN order_reviews r ON oi.order_id = r.order_id
GROUP BY p.product_category_name ORDER BY avg_rating ASC LIMIT 10;

SELECT p.product_category_name,COUNT(o.order_id) AS cancelled_orders FROM products p
JOIN order_items oi ON p.product_id = oi.product_id
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_status = 'canceled'
GROUP BY p.product_category_name ORDER BY cancelled_orders DESC LIMIT 10;

SELECT product_id,ROUND(AVG(freight_value),2) AS avg_shipping_cost FROM order_items
GROUP BY product_id ORDER BY avg_shipping_cost DESC LIMIT 10;

SELECT p.product_category_name,ROUND(SUM(op.payment_value),2) AS total_revenue FROM products p
JOIN order_items oi ON p.product_id = oi.product_id
JOIN order_payments op ON oi.order_id = op.order_id
GROUP BY p.product_category_name ORDER BY total_revenue DESC LIMIT 10;

SELECT p.product_id,p.product_category_name,COUNT(oi.order_id) AS total_sales FROM products p
LEFT JOIN order_items oi ON p.product_id = oi.product_id
GROUP BY p.product_id,p.product_category_name ORDER BY total_sales ASC LIMIT 10;

WITH category_monthly_sales AS 
(SELECT p.product_category_name AS category,DATE_FORMAT(STR_TO_DATE(o.order_purchase_timestamp,'%d-%m-%Y %H:%i'),'%Y-%m') AS month,COUNT(oi.order_id) AS total_orders FROM products p
JOIN order_items oi ON p.product_id = oi.product_id
JOIN orders o ON oi.order_id = o.order_id
GROUP BY category, month)
SELECT category,month,total_orders,LAG(total_orders) OVER(PARTITION BY category ORDER BY month) AS previous_month_orders,
ROUND(((total_orders - LAG(total_orders) OVER(PARTITION BY category ORDER BY month))/LAG(total_orders) OVER(PARTITION BY category ORDER BY month)) * 100,2) AS growth_percentage
FROM category_monthly_sales;


-- 4) SELLER ANALYSIS
SELECT COUNT(DISTINCT seller_id) AS total_sellers FROM sellers;

SELECT seller_state,COUNT(DISTINCT seller_id) AS total_sellers FROM sellers
GROUP BY seller_state ORDER BY total_sellers DESC;

SELECT s.seller_id,ROUND(SUM(op.payment_value),2) AS total_revenue FROM sellers s
JOIN order_items oi ON s.seller_id = oi.seller_id
JOIN order_payments op ON oi.order_id = op.order_id
GROUP BY s.seller_id ORDER BY total_revenue DESC LIMIT 10;

WITH seller_revenue AS 
(SELECT s.seller_id,SUM(op.payment_value) AS revenue FROM sellers s
JOIN order_items oi ON s.seller_id = oi.seller_id
JOIN order_payments op ON oi.order_id = op.order_id
GROUP BY s.seller_id)
SELECT ROUND(AVG(revenue),2) AS average_revenue_per_seller
FROM seller_revenue;

SELECT s.seller_id,MAX(STR_TO_DATE(o.order_purchase_timestamp,'%d-%m-%Y %H:%i')) AS last_sale_date FROM sellers s
JOIN order_items oi ON s.seller_id = oi.seller_id
JOIN orders o ON oi.order_id = o.order_id
GROUP BY s.seller_id HAVING last_sale_date >= DATE_SUB((SELECT MAX(STR_TO_DATE(order_purchase_timestamp,'%d-%m-%Y %H:%i')) FROM orders),INTERVAL 6 MONTH);

SELECT oi.seller_id,ROUND(AVG(DATEDIFF(STR_TO_DATE(o.order_delivered_customer_date,'%d-%m-%Y %H:%i'),STR_TO_DATE(o.order_purchase_timestamp,'%d-%m-%Y %H:%i'))),2) AS avg_delivery_days FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
GROUP BY oi.seller_id ORDER BY avg_delivery_days ASC;

SELECT oi.seller_id,ROUND(AVG(r.review_score),2) AS avg_review_score FROM order_items oi
JOIN order_reviews r ON oi.order_id = r.order_id
GROUP BY oi.seller_id ORDER BY avg_review_score DESC;

SELECT oi.seller_id,ROUND(AVG(DATEDIFF(STR_TO_DATE(o.order_delivered_customer_date,'%d-%m-%Y %H:%i'),STR_TO_DATE(o.order_estimated_delivery_date,'%d-%m-%Y %H:%i'))),2) AS avg_delay_days FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
GROUP BY oi.seller_id HAVING avg_delay_days > 0 ORDER BY avg_delay_days DESC;

WITH seller_category_revenue AS 
(SELECT p.product_category_name AS category,oi.seller_id,ROUND(SUM(op.payment_value),2) AS revenue FROM products p
JOIN order_items oi ON p.product_id = oi.product_id
JOIN order_payments op ON oi.order_id = op.order_id
GROUP BY category,oi.seller_id),
ranked_sellers AS 
(SELECT *,RANK() OVER(PARTITION BY category ORDER BY revenue DESC) AS seller_rank FROM seller_category_revenue)
SELECT category,seller_id,revenue FROM ranked_sellers
WHERE seller_rank = 1;

WITH seller_customer_orders AS 
(SELECT oi.seller_id,c.customer_unique_id,COUNT(o.order_id) AS total_orders FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
JOIN customers c ON o.customer_id = c.customer_id
GROUP BY oi.seller_id,c.customer_unique_id)
SELECT seller_id,COUNT(customer_unique_id) AS repeat_customers FROM seller_customer_orders
WHERE total_orders > 1
GROUP BY seller_id ORDER BY repeat_customers DESC;

WITH seller_revenue AS 
(SELECT oi.seller_id,ROUND(SUM(op.payment_value),2) AS total_revenue FROM order_items oi
JOIN order_payments op ON oi.order_id = op.order_id
GROUP BY oi.seller_id)
SELECT seller_id,total_revenue,
CASE
  WHEN total_revenue < 5000
  THEN 'Low Performer'
  WHEN total_revenue BETWEEN 5000 AND 50000
  THEN 'Medium Performer'
  ELSE 'High Performer'
END AS seller_segment FROM seller_revenue
ORDER BY total_revenue DESC;

WITH seller_metrics AS 
(SELECT oi.seller_id,ROUND(SUM(op.payment_value),2) AS total_revenue,COUNT(DISTINCT oi.order_id) AS total_orders,ROUND(AVG(r.review_score),2) AS avg_review_score,ROUND(AVG(DATEDIFF(STR_TO_DATE(o.order_delivered_customer_date,'%d-%m-%Y %H:%i'),STR_TO_DATE(o.order_estimated_delivery_date,'%d-%m-%Y %H:%i'))),2) AS avg_delay_days,
ROUND((SUM(
			CASE
			   WHEN o.order_status = 'canceled'
			   THEN 1
			   ELSE 0
			END)/COUNT(DISTINCT oi.order_id)) * 100,2) AS cancellation_rate FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
JOIN order_payments op ON oi.order_id = op.order_id
LEFT JOIN order_reviews r ON oi.order_id = r.order_id
GROUP BY oi.seller_id)
SELECT * FROM seller_metrics
ORDER BY total_revenue DESC;

-- 5) DELIVERY ANALYSIS
SELECT COUNT(order_id) AS delayed_deliveries FROM orders
WHERE STR_TO_DATE(order_delivered_customer_date,'%d-%m-%Y %H:%i')>STR_TO_DATE(order_estimated_delivery_date,'%d-%m-%Y %H:%i');

SELECT COUNT(order_id) AS on_time_deliveries FROM orders
WHERE STR_TO_DATE(order_delivered_customer_date,'%d-%m-%Y %H:%i')<=STR_TO_DATE(order_estimated_delivery_date,'%d-%m-%Y %H:%i');

SELECT order_id,DATEDIFF(STR_TO_DATE(order_delivered_customer_date,'%d-%m-%Y %H:%i'),STR_TO_DATE(order_purchase_timestamp,'%Y-%m-%d %H:%i:%s')) AS delivery_days FROM orders
WHERE DATEDIFF(STR_TO_DATE(order_delivered_customer_date,'%d-%m-%Y %H:%i'),
STR_TO_DATE(order_purchase_timestamp,'%d-%m-%Y %H:%i')) > 30;

SELECT DATE_FORMAT(STR_TO_DATE(order_delivered_customer_date,'%d-%m-%Y %H:%i'),'%Y-%m') AS delivery_month,COUNT(order_id) AS total_deliveries FROM orders
WHERE order_delivered_customer_date IS NOT NULL
GROUP BY delivery_month ORDER BY delivery_month;

SELECT order_id,DATEDIFF(STR_TO_DATE(order_delivered_customer_date,'%d-%m-%Y %H:%i'),STR_TO_DATE(order_estimated_delivery_date,'%d-%m-%Y %H:%i')) AS delivery_difference_days FROM orders
WHERE order_delivered_customer_date IS NOT NULL;

SELECT c.customer_state,ROUND(AVG(DATEDIFF(STR_TO_DATE(o.order_delivered_customer_date,'%d-%m-%Y %H:%i'),STR_TO_DATE(o.order_estimated_delivery_date,'%d-%m-%Y %H:%i'))),2) AS avg_delay_days FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state ORDER BY avg_delay_days DESC;

SELECT p.product_category_name,ROUND(AVG(DATEDIFF(STR_TO_DATE(o.order_delivered_customer_date,'%d-%m-%Y %H:%i'),STR_TO_DATE(o.order_purchase_timestamp,'%d-%m-%Y %H:%i'))),2) AS avg_delivery_days FROM products p
JOIN order_items oi ON p.product_id = oi.product_id
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
GROUP BY p.product_category_name ORDER BY avg_delivery_days DESC;

SELECT
 CASE
   WHEN DATEDIFF(STR_TO_DATE(o.order_delivered_customer_date,'%d-%m-%Y %H:%i'),STR_TO_DATE(o.order_estimated_delivery_date,'%d-%m-%Y %H:%i:%s')) > 0
     THEN 'Delayed'
     ELSE 'On Time'
 END AS delivery_status,
ROUND(AVG(r.review_score),2) AS avg_review_score FROM orders o
JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
GROUP BY delivery_status;

SELECT DATE_FORMAT(STR_TO_DATE(order_purchase_timestamp,'%d-%m-%Y %H:%i'),'%Y-%m') AS month,
ROUND(AVG(DATEDIFF(STR_TO_DATE(order_delivered_customer_date,'%d-%m-%Y %H:%i'),STR_TO_DATE(order_purchase_timestamp,'%d-%m-%Y %H:%i'))),2) AS avg_delivery_days FROM orders
WHERE order_delivered_customer_date IS NOT NULL
GROUP BY month ORDER BY month;

SELECT DATE_FORMAT(STR_TO_DATE(o.order_purchase_timestamp,'%d-%m-%Y %H:%i:%s'),'%Y-%m') AS month,ROUND(SUM(oi.freight_value),2) AS total_shipping_cost FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY month ORDER BY month;


-- REVIEW ANALYSIS
SELECT review_score, COUNT(review_id) AS total_reviews FROM order_reviews
GROUP BY review_score ORDER BY review_score;

SELECT p.product_category_name,ROUND(AVG(r.review_score),2) AS avg_review_score FROM products p
JOIN order_items oi ON p.product_id = oi.product_id
JOIN order_reviews r ON oi.order_id = r.order_id
GROUP BY p.product_category_name ORDER BY avg_review_score DESC LIMIT 10;

SELECT p.product_category_name,ROUND(AVG(r.review_score),2) AS avg_review_score FROM products p
JOIN order_items oi ON p.product_id = oi.product_id
JOIN order_reviews r ON oi.order_id = r.order_id
GROUP BY p.product_category_name ORDER BY avg_review_score  LIMIT 10;

SELECT p.product_id,p.product_category_name,ROUND(AVG(r.review_score),2) AS avg_review_score,COUNT(r.review_id) AS total_reviews FROM products p
JOIN order_items oi ON p.product_id = oi.product_id
JOIN order_reviews r ON oi.order_id = r.order_id
GROUP BY p.product_id,p.product_category_name HAVING total_reviews >= 5 ORDER BY avg_review_score DESC,total_reviews DESC LIMIT 10;

SELECT
   CASE
     WHEN DATEDIFF(STR_TO_DATE(o.order_delivered_customer_date,'%d-%m-%Y %H:%i'),STR_TO_DATE(o.order_estimated_delivery_date,'%d-%m-%Y %H:%i')) > 0
        THEN 'Delayed'
        ELSE 'On Time'
   END AS delivery_status, ROUND(AVG(r.review_score),2) AS avg_review_score,COUNT(r.review_id) AS total_reviews FROM orders o
JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
GROUP BY delivery_status;

SELECT oi.seller_id,ROUND(AVG(r.review_score),2) AS avg_review_score,COUNT(r.review_id) AS total_reviews FROM order_items oi
JOIN order_reviews r ON oi.order_id = r.order_id
GROUP BY oi.seller_id HAVING total_reviews >= 10 ORDER BY avg_review_score ASC LIMIT 10;

SELECT p.product_category_name,ROUND(AVG(r.review_score),2) AS avg_review_score,COUNT(r.review_id) AS total_reviews FROM products p
JOIN order_items oi ON p.product_id = oi.product_id
JOIN order_reviews r ON oi.order_id = r.order_id
GROUP BY p.product_category_name ORDER BY avg_review_score DESC;

SELECT monthname(STR_TO_DATE(r.review_creation_date,'%d-%m-%Y %H:%i:%s')) AS review_month,ROUND(AVG(r.review_score),2) AS avg_review_score,COUNT(r.review_id) AS total_reviews FROM order_reviews r
GROUP BY review_month ORDER BY review_month;

SELECT
   CASE
     WHEN oi.price < 50
	 THEN 'Low Price'
     WHEN oi.price BETWEEN 50 AND 200
     THEN 'Medium Price'
     ELSE 'High Price'
   END AS price_segment,ROUND(AVG(r.review_score),2) AS avg_review_score,COUNT(r.review_id) AS total_reviews FROM order_items oi
JOIN order_reviews r ON oi.order_id = r.order_id
GROUP BY price_segment;