-- ============================================================
-- NYKAA BEAUTY & FASHION - REAL-TIME BUSINESS ANALYTICS
-- ============================================================

USE Nykaa_Analytics;

-- BUSINESS QUESTIONS

-- 1. Which customers have ordered products, and what is their latest order status?
SELECT
    c.customer_id,
    CONCAT(c.first_name,' ',c.last_name) AS customer_name,
    o.order_id,
    o.order_date,
    o.final_amount,
    o.shipping_status
FROM System_Customers c
JOIN System_Orders o
    ON c.customer_id = o.customer_id
ORDER BY o.order_date DESC;

-- 2. Which registered customers have never placed an order?
SELECT
    c.customer_id,
    CONCAT(c.first_name,' ',c.last_name) AS customer_name,
    COUNT(o.order_id) AS total_orders
FROM System_Customers c
LEFT JOIN System_Orders o
    ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
HAVING COUNT(o.order_id) = 0;

-- 3. Which Beauty products are priced above the Beauty catalogue average?
SELECT
    product_id,
    product_name,
    price
FROM Beauty_Products
WHERE price > (SELECT AVG(price) FROM Beauty_Products)
ORDER BY price DESC;

-- 4. Which customers spend more than the average spending of a delivered-order customer?
SELECT
    c.customer_id,
    CONCAT(c.first_name,' ',c.last_name) AS customer_name,
    SUM(o.final_amount) AS total_spending
FROM System_Customers c
JOIN System_Orders o
    ON c.customer_id = o.customer_id
WHERE o.shipping_status = 'Delivered'
GROUP BY c.customer_id, c.first_name, c.last_name
HAVING SUM(o.final_amount) >
(
    SELECT AVG(customer_total)
    FROM
    (
        SELECT customer_id, SUM(final_amount) AS customer_total
        FROM System_Orders
        WHERE shipping_status = 'Delivered'
        GROUP BY customer_id
    ) AS avg_customer
)
ORDER BY total_spending DESC;

-- 5. How should customers be grouped according to their delivered-order spending?
WITH customer_sales AS
(
    SELECT
        customer_id,
        COUNT(order_id) AS total_orders,
        SUM(final_amount) AS total_spending
    FROM System_Orders
    WHERE shipping_status = 'Delivered'
    GROUP BY customer_id
)
SELECT
    c.customer_id,
    CONCAT(c.first_name,' ',c.last_name) AS customer_name,
    cs.total_orders,
    cs.total_spending,
    CASE
        WHEN cs.total_spending >= 20000 THEN 'High Value'
        WHEN cs.total_spending >= 10000 THEN 'Medium Value'
        ELSE 'Regular Value'
    END AS customer_segment
FROM customer_sales cs
JOIN System_Customers c ON cs.customer_id = c.customer_id
ORDER BY cs.total_spending DESC;

-- 6. Which months generated the highest delivered sales revenue over time?
WITH monthly_sales AS
(
    SELECT
        DATE_FORMAT(order_date,'%Y-%m') AS sales_month,
        SUM(final_amount) AS revenue
    FROM System_Orders
    WHERE shipping_status = 'Delivered'
    GROUP BY DATE_FORMAT(order_date,'%Y-%m')
)
SELECT sales_month, revenue
FROM monthly_sales
ORDER BY sales_month;

-- 7. Which customers purchase from both Beauty and Fashion and are suitable for cross-selling?
WITH beauty_customers AS
(
    SELECT DISTINCT o.customer_id
    FROM System_Orders o
    JOIN Beauty_Order_Items boi ON o.order_id = boi.order_id
    WHERE o.shipping_status = 'Delivered'
),
fashion_customers AS
(
    SELECT DISTINCT o.customer_id
    FROM System_Orders o
    JOIN Fashion_Order_Items foi ON o.order_id = foi.order_id
    WHERE o.shipping_status = 'Delivered'
)
SELECT
    c.customer_id,
    CONCAT(c.first_name,' ',c.last_name) AS customer_name,
    c.membership_tier
FROM System_Customers c
JOIN beauty_customers b ON c.customer_id = b.customer_id
JOIN fashion_customers f ON c.customer_id = f.customer_id
ORDER BY c.customer_id;

-- 8. Which customers are the highest spenders across the entire customer base?
WITH customer_sales AS
(
    SELECT
        c.customer_id,
        CONCAT(c.first_name,' ',c.last_name) AS customer_name,
        c.membership_tier,
        SUM(o.final_amount) AS total_spending
    FROM System_Customers c
    JOIN System_Orders o ON c.customer_id = o.customer_id
    WHERE o.shipping_status = 'Delivered'
    GROUP BY c.customer_id, c.first_name, c.last_name, c.membership_tier
)
SELECT
    customer_id,
    customer_name,
    membership_tier,
    total_spending,
    RANK() OVER (ORDER BY total_spending DESC) AS spending_rank
FROM customer_sales
ORDER BY spending_rank;

-- 9. Who are the top three customers within each membership tier?
WITH customer_sales AS
(
    SELECT
        c.customer_id,
        CONCAT(c.first_name,' ',c.last_name) AS customer_name,
        c.membership_tier,
        SUM(o.final_amount) AS total_spending
    FROM System_Customers c
    JOIN System_Orders o ON c.customer_id = o.customer_id
    WHERE o.shipping_status = 'Delivered'
    GROUP BY c.customer_id, c.first_name, c.last_name, c.membership_tier
),
ranked_customers AS
(
    SELECT
        *,
        ROW_NUMBER() OVER
        (
            PARTITION BY membership_tier
            ORDER BY total_spending DESC
        ) AS tier_rank
    FROM customer_sales
)
SELECT *
FROM ranked_customers
WHERE tier_rank <= 3
ORDER BY membership_tier, tier_rank;

-- 10. How is monthly revenue changing compared with the previous month?
WITH monthly_sales AS
(
    SELECT
        DATE_FORMAT(order_date,'%Y-%m') AS sales_month,
        SUM(final_amount) AS revenue
    FROM System_Orders
    WHERE shipping_status = 'Delivered'
    GROUP BY DATE_FORMAT(order_date,'%Y-%m')
)
SELECT
    sales_month,
    revenue,
    LAG(revenue) OVER (ORDER BY sales_month) AS previous_month_revenue,
    ROUND(
        (revenue - LAG(revenue) OVER (ORDER BY sales_month))
        / NULLIF(LAG(revenue) OVER (ORDER BY sales_month),0) * 100,
        2
    ) AS growth_percentage
FROM monthly_sales
ORDER BY sales_month;

-- 11. Which Beauty products rank highest by delivered sales revenue?
WITH beauty_product_sales AS
(
    SELECT
        bp.product_id,
        bp.product_name,
        SUM(boi.quantity * boi.price_at_purchase) AS revenue
    FROM Beauty_Products bp
    JOIN Beauty_Order_Items boi ON bp.product_id = boi.product_id
    JOIN System_Orders o ON boi.order_id = o.order_id
    WHERE o.shipping_status = 'Delivered'
    GROUP BY bp.product_id, bp.product_name
)
SELECT
    product_id,
    product_name,
    revenue,
    DENSE_RANK() OVER (ORDER BY revenue DESC) AS revenue_rank
FROM beauty_product_sales
ORDER BY revenue_rank;

-- 12. Which payment method generates the most delivered revenue?
SELECT
    payment_method,
    COUNT(*) AS total_orders,
    SUM(final_amount) AS revenue,
    ROUND(AVG(final_amount),2) AS average_order_value
FROM System_Orders
WHERE shipping_status = 'Delivered'
GROUP BY payment_method
ORDER BY revenue DESC;

-- 13. Which Beauty category generates the most delivered revenue?
SELECT
    bc.category_name,
    SUM(boi.quantity * boi.price_at_purchase) AS revenue
FROM Beauty_Categories bc
JOIN Beauty_Products bp ON bc.category_id = bp.category_id
JOIN Beauty_Order_Items boi ON bp.product_id = boi.product_id
JOIN System_Orders o ON boi.order_id = o.order_id
WHERE o.shipping_status = 'Delivered'
GROUP BY bc.category_name
ORDER BY revenue DESC;

-- 14. Which Fashion category generates the most delivered revenue?
SELECT
    fc.category_name,
    SUM(foi.quantity * foi.price_at_purchase) AS revenue
FROM Fashion_Categories fc
JOIN Fashion_Products fp ON fc.category_id = fp.category_id
JOIN Fashion_Order_Items foi ON fp.product_id = foi.product_id
JOIN System_Orders o ON foi.order_id = o.order_id
WHERE o.shipping_status = 'Delivered'
GROUP BY fc.category_name
ORDER BY revenue DESC;

-- 15. Which products are low in stock and need replenishment attention?
SELECT
    'Beauty' AS product_segment,
    product_id,
    product_name,
    stock_quantity
FROM Beauty_Products
WHERE stock_quantity <= 30
UNION ALL
SELECT
    'Fashion',
    product_id,
    product_name,
    stock_quantity
FROM Fashion_Products
WHERE stock_quantity <= 30
ORDER BY stock_quantity;

-- 16. Which Beauty brands combine strong revenue with customer ratings of at least four stars?
WITH beauty_brand_sales AS
(
    SELECT
        bb.brand_id,
        bb.brand_name,
        SUM(boi.quantity * boi.price_at_purchase) AS revenue
    FROM Beauty_Brands bb
    JOIN Beauty_Products bp ON bb.brand_id = bp.brand_id
    JOIN Beauty_Order_Items boi ON bp.product_id = boi.product_id
    JOIN System_Orders o ON boi.order_id = o.order_id
    WHERE o.shipping_status = 'Delivered'
    GROUP BY bb.brand_id, bb.brand_name
),
beauty_brand_ratings AS
(
    SELECT
        bp.brand_id,
        AVG(r.rating) AS average_rating
    FROM Beauty_Products bp
    JOIN System_Product_Reviews r
      ON r.product_segment = 'Beauty'
     AND r.product_id = bp.product_id
    GROUP BY bp.brand_id
)
SELECT
    bbs.brand_name,
    ROUND(bbs.revenue,2) AS revenue,
    ROUND(bbr.average_rating,2) AS average_rating
FROM beauty_brand_sales bbs
JOIN beauty_brand_ratings bbr ON bbs.brand_id = bbr.brand_id
WHERE bbr.average_rating >= 4
ORDER BY bbs.revenue DESC;

-- ============================================================
-- ADDITIONAL BUSINESS QUESTIONS
-- ============================================================

-- 17. Which customers are placing repeat orders and should be targeted for loyalty campaigns?
SELECT
    c.customer_id,
    CONCAT(c.first_name,' ',c.last_name) AS customer_name,
    c.membership_tier,
    COUNT(o.order_id) AS delivered_orders,
    ROUND(SUM(o.final_amount),2) AS total_spending,
    ROUND(AVG(o.final_amount),2) AS average_order_value
FROM System_Customers c
JOIN System_Orders o ON c.customer_id = o.customer_id
WHERE o.shipping_status = 'Delivered'
GROUP BY c.customer_id, c.first_name, c.last_name, c.membership_tier
HAVING COUNT(o.order_id) >= 2
ORDER BY delivered_orders DESC, total_spending DESC;

-- 18. Which customers have cancelled orders frequently and may require retention intervention?
SELECT
    c.customer_id,
    CONCAT(c.first_name,' ',c.last_name) AS customer_name,
    COUNT(o.order_id) AS total_orders,
    SUM(o.shipping_status = 'Cancelled') AS cancelled_orders,
    ROUND(100 * SUM(o.shipping_status = 'Cancelled') / COUNT(o.order_id),2) AS cancellation_rate
FROM System_Customers c
JOIN System_Orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
HAVING cancellation_rate >= 25
ORDER BY cancellation_rate DESC;

-- 19. How much revenue and order value comes from each membership tier?
SELECT
    c.membership_tier,
    COUNT(DISTINCT c.customer_id) AS customers,
    COUNT(o.order_id) AS delivered_orders,
    ROUND(SUM(o.final_amount),2) AS revenue,
    ROUND(AVG(o.final_amount),2) AS average_order_value
FROM System_Customers c
LEFT JOIN System_Orders o
    ON c.customer_id = o.customer_id
   AND o.shipping_status = 'Delivered'
GROUP BY c.membership_tier
ORDER BY revenue DESC;

-- 20. Which coupons are driving the highest sales value and average order value?
SELECT
    cp.coupon_code,
    cp.discount_percentage,
    COUNT(o.order_id) AS used_orders,
    ROUND(SUM(o.final_amount),2) AS revenue,
    ROUND(AVG(o.final_amount),2) AS average_order_value
FROM System_Coupons cp
JOIN System_Orders o ON cp.coupon_id = o.coupon_id
WHERE o.shipping_status = 'Delivered'
GROUP BY cp.coupon_id, cp.coupon_code, cp.discount_percentage
ORDER BY revenue DESC;

-- 21. Which orders received the largest monetary discount and should be evaluated for promotion profitability?
SELECT
    o.order_id,
    o.customer_id,
    cp.coupon_code,
    o.subtotal_amount,
    o.final_amount,
    ROUND(o.subtotal_amount - o.final_amount,2) AS discount_value
FROM System_Orders o
JOIN System_Coupons cp ON o.coupon_id = cp.coupon_id
WHERE o.shipping_status = 'Delivered'
ORDER BY discount_value DESC
LIMIT 20;

-- 22. Which orders have been waiting too long for delivery or shipment?
SELECT
    order_id,
    customer_id,
    order_date,
    shipping_status,
    TIMESTAMPDIFF(DAY, order_date, NOW()) AS days_since_order,
    final_amount
FROM System_Orders
WHERE shipping_status IN ('Pending','Shipped')
  AND order_date < NOW() - INTERVAL 7 DAY
ORDER BY days_since_order DESC;

-- 23. Which payment methods are associated with the highest cancellation rate?
SELECT
    payment_method,
    COUNT(*) AS total_orders,
    SUM(shipping_status = 'Cancelled') AS cancelled_orders,
    ROUND(100 * SUM(shipping_status = 'Cancelled') / COUNT(*),2) AS cancellation_rate
FROM System_Orders
GROUP BY payment_method
ORDER BY cancellation_rate DESC;

-- 24. Which products have never generated a sale and may need merchandising or pricing action?
SELECT
    'Beauty' AS product_segment,
    bp.product_id,
    bp.product_name,
    bp.price,
    bp.stock_quantity
FROM Beauty_Products bp
LEFT JOIN Beauty_Order_Items boi ON bp.product_id = boi.product_id
WHERE boi.product_id IS NULL
UNION ALL
SELECT
    'Fashion',
    fp.product_id,
    fp.product_name,
    fp.price,
    fp.stock_quantity
FROM Fashion_Products fp
LEFT JOIN Fashion_Order_Items foi ON fp.product_id = foi.product_id
WHERE foi.product_id IS NULL
ORDER BY product_segment, stock_quantity DESC;

-- 25. Which Beauty products generate the most units sold and should receive stronger inventory support?
SELECT
    bp.product_id,
    bp.product_name,
    SUM(boi.quantity) AS units_sold,
    ROUND(SUM(boi.quantity * boi.price_at_purchase),2) AS revenue
FROM Beauty_Products bp
JOIN Beauty_Order_Items boi ON bp.product_id = boi.product_id
JOIN System_Orders o ON boi.order_id = o.order_id
WHERE o.shipping_status = 'Delivered'
GROUP BY bp.product_id, bp.product_name
ORDER BY units_sold DESC, revenue DESC
LIMIT 20;

-- 26. Which Fashion products generate the most revenue and should receive stronger inventory support?
SELECT
    fp.product_id,
    fp.product_name,
    SUM(foi.quantity) AS units_sold,
    ROUND(SUM(foi.quantity * foi.price_at_purchase),2) AS revenue
FROM Fashion_Products fp
JOIN Fashion_Order_Items foi ON fp.product_id = foi.product_id
JOIN System_Orders o ON foi.order_id = o.order_id
WHERE o.shipping_status = 'Delivered'
GROUP BY fp.product_id, fp.product_name
ORDER BY revenue DESC, units_sold DESC
LIMIT 20;

-- 27. Which Beauty products have both strong sales and low remaining stock, creating replenishment risk?
SELECT
    bp.product_id,
    bp.product_name,
    bp.stock_quantity,
    SUM(boi.quantity) AS units_sold,
    ROUND(SUM(boi.quantity * boi.price_at_purchase),2) AS revenue
FROM Beauty_Products bp
JOIN Beauty_Order_Items boi ON bp.product_id = boi.product_id
JOIN System_Orders o ON boi.order_id = o.order_id
WHERE o.shipping_status = 'Delivered'
GROUP BY bp.product_id, bp.product_name, bp.stock_quantity
HAVING bp.stock_quantity <= 30 AND units_sold >= 5
ORDER BY bp.stock_quantity, units_sold DESC;

-- 28. Which Fashion products have strong demand but limited stock and should be replenished quickly?
SELECT
    fp.product_id,
    fp.product_name,
    fp.stock_quantity,
    SUM(foi.quantity) AS units_sold,
    ROUND(SUM(foi.quantity * foi.price_at_purchase),2) AS revenue
FROM Fashion_Products fp
JOIN Fashion_Order_Items foi ON fp.product_id = foi.product_id
JOIN System_Orders o ON foi.order_id = o.order_id
WHERE o.shipping_status = 'Delivered'
GROUP BY fp.product_id, fp.product_name, fp.stock_quantity
HAVING fp.stock_quantity <= 30 AND units_sold >= 5
ORDER BY fp.stock_quantity, units_sold DESC;

-- 29. Which products are approaching expiry and still have stock available?
SELECT
    'Beauty' AS product_segment,
    product_id,
    product_name,
    expiry_date,
    stock_quantity,
    DATEDIFF(expiry_date, CURDATE()) AS days_to_expiry
FROM Beauty_Products
WHERE expiry_date BETWEEN CURDATE() AND CURDATE() + INTERVAL 90 DAY
  AND stock_quantity > 0
ORDER BY expiry_date
LIMIT 50;

-- 30. Which Beauty categories receive the best customer ratings and can be promoted?
SELECT
    bc.category_name,
    COUNT(r.review_id) AS review_count,
    ROUND(AVG(r.rating),2) AS average_rating
FROM Beauty_Categories bc
JOIN Beauty_Products bp ON bc.category_id = bp.category_id
JOIN System_Product_Reviews r
    ON r.product_segment = 'Beauty'
   AND r.product_id = bp.product_id
GROUP BY bc.category_id, bc.category_name
HAVING COUNT(r.review_id) >= 5
ORDER BY average_rating DESC, review_count DESC;

-- 31. Which Fashion categories have the highest proportion of fit-related complaints?
SELECT
    fc.category_name,
    COUNT(r.review_id) AS total_reviews,
    SUM(r.fit_feedback IN ('Too Small','Too Large')) AS fit_issue_reviews,
    ROUND(
        100 * SUM(r.fit_feedback IN ('Too Small','Too Large')) / COUNT(r.review_id),
        2
    ) AS fit_issue_rate
FROM Fashion_Categories fc
JOIN Fashion_Products fp ON fc.category_id = fp.category_id
JOIN System_Product_Reviews r
    ON r.product_segment = 'Fashion'
   AND r.product_id = fp.product_id
GROUP BY fc.category_id, fc.category_name
HAVING COUNT(r.review_id) >= 5
ORDER BY fit_issue_rate DESC;

-- 32. Which customers buy Beauty products but have not yet purchased Fashion products?
SELECT
    c.customer_id,
    CONCAT(c.first_name,' ',c.last_name) AS customer_name,
    c.membership_tier
FROM System_Customers c
WHERE EXISTS
(
    SELECT 1
    FROM System_Orders o
    JOIN Beauty_Order_Items boi ON o.order_id = boi.order_id
    WHERE o.customer_id = c.customer_id
      AND o.shipping_status = 'Delivered'
)
AND NOT EXISTS
(
    SELECT 1
    FROM System_Orders o
    JOIN Fashion_Order_Items foi ON o.order_id = foi.order_id
    WHERE o.customer_id = c.customer_id
      AND o.shipping_status = 'Delivered'
)
ORDER BY c.membership_tier, c.customer_id;

-- 33. Which customers buy Fashion products but have not yet purchased Beauty products?
SELECT
    c.customer_id,
    CONCAT(c.first_name,' ',c.last_name) AS customer_name,
    c.membership_tier
FROM System_Customers c
WHERE EXISTS
(
    SELECT 1
    FROM System_Orders o
    JOIN Fashion_Order_Items foi ON o.order_id = foi.order_id
    WHERE o.customer_id = c.customer_id
      AND o.shipping_status = 'Delivered'
)
AND NOT EXISTS
(
    SELECT 1
    FROM System_Orders o
    JOIN Beauty_Order_Items boi ON o.order_id = boi.order_id
    WHERE o.customer_id = c.customer_id
      AND o.shipping_status = 'Delivered'
)
ORDER BY c.membership_tier, c.customer_id;

-- 34. At which hours does Nykaa receive the most orders, helping operations plan staffing?
SELECT
    HOUR(order_date) AS order_hour,
    COUNT(*) AS total_orders,
    ROUND(AVG(final_amount),2) AS average_order_value
FROM System_Orders
GROUP BY HOUR(order_date)
ORDER BY total_orders DESC, order_hour;

-- 35. Which months generated the highest delivered revenue?
SELECT
    DATE_FORMAT(order_date,'%Y-%m') AS sales_month,
    COUNT(*) AS delivered_orders,
    ROUND(SUM(final_amount),2) AS revenue,
    ROUND(AVG(final_amount),2) AS average_order_value
FROM System_Orders
WHERE shipping_status = 'Delivered'
GROUP BY DATE_FORMAT(order_date,'%Y-%m')
ORDER BY revenue DESC;

-- 36. Which customers have both high spending and a high average order value for premium retention offers?
SELECT
    c.customer_id,
    CONCAT(c.first_name,' ',c.last_name) AS customer_name,
    c.membership_tier,
    COUNT(o.order_id) AS delivered_orders,
    ROUND(SUM(o.final_amount),2) AS total_spending,
    ROUND(AVG(o.final_amount),2) AS average_order_value
FROM System_Customers c
JOIN System_Orders o ON c.customer_id = o.customer_id
WHERE o.shipping_status = 'Delivered'
GROUP BY c.customer_id, c.first_name, c.last_name, c.membership_tier
HAVING SUM(o.final_amount) >= 20000
   AND AVG(o.final_amount) >= 5000
ORDER BY total_spending DESC;

-- 37. What are the overall revenue, order and average order value KPIs?
SELECT
    COUNT(DISTINCT customer_id) AS customers_with_orders,
    COUNT(order_id) AS total_orders,
    ROUND(SUM(final_amount),2) AS total_revenue,
    ROUND(AVG(final_amount),2) AS average_order_value
FROM System_Orders
WHERE shipping_status = 'Delivered';

-- 38. Which membership tier contributes the most delivered revenue?
SELECT
    c.membership_tier,
    COUNT(DISTINCT c.customer_id) AS customers,
    COUNT(o.order_id) AS delivered_orders,
    ROUND(SUM(o.final_amount),2) AS revenue,
    ROUND(AVG(o.final_amount),2) AS average_order_value
FROM System_Customers c
LEFT JOIN System_Orders o
    ON c.customer_id = o.customer_id
    AND o.shipping_status = 'Delivered'
GROUP BY c.membership_tier
ORDER BY revenue DESC;

-- 39. How many customers currently buy from both Beauty and Fashion?
WITH beauty AS
(
    SELECT DISTINCT o.customer_id
    FROM System_Orders o
    JOIN Beauty_Order_Items i ON o.order_id = i.order_id
    WHERE o.shipping_status = 'Delivered'
),
fashion AS
(
    SELECT DISTINCT o.customer_id
    FROM System_Orders o
    JOIN Fashion_Order_Items i ON o.order_id = i.order_id
    WHERE o.shipping_status = 'Delivered'
)
SELECT COUNT(*) AS customers_buying_both_segments
FROM beauty b
JOIN fashion f ON b.customer_id = f.customer_id;

-- 40. Which ten customers should receive the highest-priority retention offers?
WITH customer_sales AS
(
    SELECT
        customer_id,
        COUNT(order_id) AS total_orders,
        SUM(final_amount) AS total_spending
    FROM System_Orders
    WHERE shipping_status = 'Delivered'
    GROUP BY customer_id
)
SELECT
    c.customer_id,
    CONCAT(c.first_name,' ',c.last_name) AS customer_name,
    c.membership_tier,
    cs.total_orders,
    cs.total_spending
FROM customer_sales cs
JOIN System_Customers c ON cs.customer_id = c.customer_id
ORDER BY cs.total_spending DESC
LIMIT 10;


-- ============================================================
-- ADDITIONAL BUSINESS QUESTIONS
-- ============================================================
