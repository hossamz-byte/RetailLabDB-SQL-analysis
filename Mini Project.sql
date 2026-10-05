--Support team: list OrderID, CustomerName, City, OrderDate, OrderStatus.

select o.orderid ,
c.customername,
c.city,
o.orderdate,
o.orderstatus
from orders o join customers c 
on c.CustomerID=o.CustomerID
--Sales lines: each order line with ProductName, Category, Quantity, and line revenue.

select od.orderid,
p.productname,
p.category,
od.quantity,
od.quantity* od.unitprice*(1-discount) as Line_Revenue
from products p join orderdetails od
on p.ProductID=od.ProductID
order by OrderID,Line_Revenue
--Finance: count and revenue of Completed orders per PaymentMethod.
select PaymentMethod,
count(distinct o.orderid) as Order_Count,
sum(od.quantity* od.unitprice*(1-discount)) as Total_Revenue
from orderdetails od join orders o 
on o.orderid= od.orderid 
where OrderStatus='Completed'
group by PaymentMethod 


--Category report: net revenue by Category and SubCategory, highest first.

select category,
SubCategory,
sum(od.Quantity * od.UnitPrice * (1 - od.Discount)) as Net_Revenue
from orderdetails od join products p
on p.productid=od.productid
join orders o on od.orderid=o.orderid
where orderstatus ='Completed'
group by Category,SubCategory
order by 3


--Segment report: revenue, order count, and average order value per CustomerSegment.

select c.CustomerSegment, 
count(distinct o.orderid) as ordercount,
sum(od.Quantity * od.UnitPrice * (1 - od.Discount)) as Net_Revenue,
sum(od.Quantity * od.UnitPrice * (1 - od.Discount))/count(distinct o.orderid)
from customers c join orders o
on o.CustomerID=c.CustomerID
join orderdetails od 
on o.orderid=od.orderid
where orderstatus ='Completed'
group by c.CustomerSegment


--Trend: revenue per month for the last 12 months.

select 
year(orderdate) as year,
month(orderdate) as month,
sum(od.Quantity * od.UnitPrice * (1 - od.Discount)) as Net_Revenue
from Orders o JOIN OrderDetails od 
on o.OrderID = od.OrderID
where OrderStatus='Completed'and orderdate >= DATEADD(month,-12,cast(getdate() as date))
group by  year(orderdate),
month(orderdate) 
order by 1 ,2


--VIPs: top 10 customers by lifetime spend.

select top(10)with ties 
c.CustomerID,
customername,
CustomerSegment,
sum(od.Quantity * od.UnitPrice * (1 - od.Discount)) AS Lifetime_Spend
from customers c join orders o
on o.CustomerID=c.CustomerID join orderdetails od 
on o.orderid=od.orderid
where orderstatus ='Completed'
group by c.CustomerID,customername,CustomerSegment
order by Lifetime_Spend desc

--Geography: revenue by customer City vs by ShippingCity. Do they tell different stories?

with Cust_city as(
select c.city,
sum(od.Quantity * od.UnitPrice * (1 - od.Discount)) AS [Revenue By Customercity]
from customers c join orders o
on o.CustomerID=c.CustomerID join orderdetails od 
on o.orderid=od.orderid
where orderstatus ='Completed'
group by c.city )
, Ship_city as (
select o.ShippingCity,
sum(od.Quantity * od.UnitPrice * (1 - od.Discount)) AS [Revenue By Shippingcity]
from  orders o join orderdetails od 
on o.orderid=od.orderid
where orderstatus ='Completed'
group by o.ShippingCity
)
select cc.city,
[Revenue By Customercity],
[Revenue By Shippingcity],
[Revenue By Customercity] - [Revenue By Shippingcity] as Difference
from Ship_city sc join Cust_city cc
on cc.city=sc.ShippingCity


--Marketing: customers with no Completed orders Check how many you get and look for a pattern in their IDs.

select 
c.customerid,
c.customername,
c.city
from customers c left join orders o
on c.CustomerID=o.CustomerID and o.orderstatus ='completed'
where o.orderid is null

/'

select   c.CustomerID,customername,city
from customers c  
where not exists (
select 1 from orders o 
where o.CustomerID=c.customerid and OrderStatus='Completed')
'/


--Ops: customers who have only Pending orders.
select   c.CustomerID,customername,city
from customers c  
where  exists (
select 1 from orders o 
where o.CustomerID=c.customerid and OrderStatus='Pending')
and not exists (
select 1 from orders o 
where o.CustomerID=c.customerid and orderstatus <> 'pending')


--Risk: cancellation rate by PaymentMethod and by ShippingCity.

with cte as(
select PaymentMethod,ShippingCity,case when orderstatus='cancelled' then 1 else 0 end
as cancelled
from orders
)
select 
'PaymentMethod'GroupType,
PaymentMethod GroupValue,
 sum (cancelled) cancelledcounts,
 sum(cancelled) * 100.0 / count(*) as rate
from cte
group by PaymentMethod
union all
select 
'ShippingCity'GroupType,
ShippingCity GroupValue,
 sum (cancelled) cancelledcounts,
 sum(cancelled) * 100.0 / count(*) as rate
from cte
group by ShippingCity
order by rate desc,GroupType


--Mismatch: orders where ShippingCity differs from the customers City, and their share of total revenue.
with cte as (
select orderid ,case when ShippingCity <>c.City then 1 else 0
end as notmatch 
from customers c join orders o 
on c.CustomerID=o.CustomerID
),Revenue as(
select
sum(case when notmatch=1 then od.Quantity * od.UnitPrice *(1-discount)
end ) as Mismatch_Revenue,
sum(od.Quantity * od.UnitPrice *(1-discount)) Total_Revenue 
from cte c join OrderDetails od
on c.OrderID =od.orderid
)
select Mismatch_Revenue,
Total_Revenue,
Mismatch_Revenue*100.0/Total_Revenue as Sharepct
from Revenue


--Discount impact: gross vs net revenue and total discount lost, per Category.

select category,
sum(od.Quantity * od.UnitPrice) as gross,
sum(od.Quantity * od.UnitPrice * (1-discount)) as net_revenue,
sum(od.Quantity * od.UnitPrice * discount)  as DiscountLost,
sum(od.Quantity * od.UnitPrice * discount) * 100/sum(od.Quantity * od.UnitPrice) as DiscountPCT
from products p join orderdetails od
on p.ProductID=od.ProductID
group by Category

--Discount strategy: which discount level (0 to 30%) sells the most units on average?

select discount,
count(*) as lines ,
sum(Quantity)as totalunits,
avg(1.0 * quantity) as Avgunitsperline
from orderdetails 
group by discount


--Low stock alert: products where StockQuantity is lower than units sold in the last 90 days.

select p.ProductID,
p.ProductName,
p.StockQuantity
from products p join OrderDetails od
on p.ProductID=od.ProductID join orders o 
on o.Orderid=od.orderid
where orderdate >=dateadd(day,-90,(select max(orderdate)from orders)) 
and OrderStatus<>'cancelled'
group by p.ProductID, p.ProductName, p.StockQuantity
having StockQuantity < sum(Quantity)	


--Price check: order lines where the sale UnitPrice differs from the current Products.UnitPrice.(Expect none, so state it as a data-quality check.)
if exists (
	select 1
	from products p join orderdetails od 
	on p.ProductID=od.ProductID
	where od.UnitPrice <> p.UnitPrice
	)
begin
	select 
	OrderDetailID,
	orderid,
	p.UnitPrice as ProductPrice,
	od.UnitPrice as SalesPrice,
	p.UnitPrice - od.UnitPrice as Differences
	from products p join orderdetails od 
	on p.ProductID=od.ProductID
	where od.UnitPrice <> p.UnitPrice
end
else
	select 'They all same price Data is good' As Datacheck

