USE final;

CREATE TABLE transactions_info (
date_new varchar(10),
Id_check int,
ID_client int,
Count_products double,
Sum_payment double);

LOAD DATA INFILE 'C:\\ProgramData\\MySQL\\MySQL Server 8.0\\Uploads\\transactions_info.xlsx - TRANSACTIONS.csv'
INTO TABLE transactions_info
FIELDS TERMINATED BY ',' 
LINES TERMINATED BY '\n' 
IGNORE 1 ROWS;

SELECT * FROM transactions_info;

RENAME TABLE `customer_info.xlsx - query_for_abt_customerinfo_0002` TO customer_info;

SELECT * FROM customer_info;

/*список клиентов с непрерывной историей за год, то есть каждый месяц на регулярной основе без пропусков за указанный годовой период*/
SELECT ID_client
FROM (
    SELECT ID_client,
	COUNT(DISTINCT DATE_FORMAT(STR_TO_DATE(date_new, '%d/%m/%Y'), '%Y-%m')) AS month_count
    FROM transactions_info
    WHERE STR_TO_DATE(date_new, '%d/%m/%Y') BETWEEN '2015-06-01' AND '2016-06-01'
    GROUP BY ID_client
) AS monthly_summary
WHERE month_count = 12;

/*средний чек за период с 01.06.2015 по 01.06.2016*/
SELECT AVG(Sum_payment)
FROM transactions_info
WHERE STR_TO_DATE(date_new, '%d/%m/%Y') BETWEEN '2015-06-01' AND '2016-06-01'

/*средняя сумма покупок за месяц*/
SELECT DATE_FORMAT(STR_TO_DATE(date_new, '%d/%m/%Y'), '%Y-%m') AS month,
	AVG(Sum_payment)
FROM transactions_info
WHERE STR_TO_DATE(date_new, '%d/%m/%Y') BETWEEN '2015-06-01' AND '2016-06-01' -- не знала точно нужно это тут или нет но пусть будет
GROUP BY month;

/*количество всех операций по клиенту за период*/
SELECT ID_client, COUNT(DISTINCT Id_check)
FROM transactions_info
WHERE STR_TO_DATE(date_new, '%d/%m/%Y') BETWEEN '2015-06-01' AND '2016-06-01' 
GROUP BY ID_client;

/*средняя сумма чека в месяц*/
SELECT Id_check, DATE_FORMAT(STR_TO_DATE(date_new, '%d/%m/%Y'), '%Y-%m')AS month, AVG(Sum_payment)
FROM transactions_info
GROUP BY month, Id_check;

/*среднее количество операций в месяц*/
SELECT month, AVG(operation_count) AS average_operations
FROM (
	SELECT DATE_FORMAT(STR_TO_DATE(date_new, '%d/%m/%Y'), '%Y-%m')AS month, 
			COUNT(DISTINCT Id_check) AS operation_count
	FROM transactions_info
	GROUP BY month
) AS monthly_operations
GROUP BY month;

/*среднее количество клиентов, которые совершали операции*/
SELECT month, AVG(client_count) AS average_amount_of_clients
FROM (
	SELECT DATE_FORMAT(STR_TO_DATE(date_new, '%d/%m/%Y'), '%Y-%m')AS month, 
			COUNT(DISTINCT ID_client) AS client_count
	FROM transactions_info
    WHERE Id_check IS NOT NULL
	GROUP BY month
) AS monthly_amount_of_clients
GROUP BY month;

/*долю от общего количества операций за год и долю в месяц от общей суммы операций*/
SELECT month, 
	operation_count,
    total_sum,
    ROUND(operation_count / yearly_total_operations * 100, 2) AS operation_share_percentage,
    ROUND(total_sum / yearly_total_sum * 100, 2) AS total_sum_share_percentage
FROM (
    -- подсчет операций и суммы по месяцам
    SELECT 
        DATE_FORMAT(STR_TO_DATE(date_new, '%d/%m/%Y'), '%Y-%m') AS month,
        COUNT(Id_check) AS operation_count,
        ROUND(SUM(Sum_payment),2) AS total_sum,
        
        (SELECT COUNT(Id_check) 
        FROM transactions_info) AS yearly_total_operations,
        
        (SELECT SUM(Sum_payment) 
        FROM transactions_info) AS yearly_total_sum
        
    FROM transactions_info
    WHERE STR_TO_DATE(date_new, '%d/%m/%Y') BETWEEN '2015-06-01' AND '2016-06-01'
    GROUP BY month
) AS monthly_summary
ORDER BY month;

/*вывести % соотношение M/F/NA в каждом месяце с их долей затрат*/
SELECT month, gender, customer_count,
    ROUND(customer_count / total_monthly_customers * 100, 2) AS gender_percentage,
    total_spent,
    ROUND(total_spent / total_monthly_spent * 100, 2) AS spent_percentage
FROM (
    -- расчет кол-ва клиентов и суммы по каждому полу и месяцу
    SELECT DATE_FORMAT(STR_TO_DATE(t.date_new, '%d/%m/%Y'), '%Y-%m') AS month,
			c.gender, 
			COUNT(*) AS customer_count,
			ROUND(SUM(t.Sum_payment),2) AS total_spent,
        
        -- общ кол-ва клиентов в месяц
			(SELECT COUNT(*) 
			 FROM transactions_info t2
			 JOIN customer_info c2 ON t2.ID_client = c2.Id_client
			 ) AS total_monthly_customers,
         
        -- общ сумма трат в месяц
			(SELECT SUM(t2.Sum_payment)
			 FROM transactions_info t2
			 ) AS total_monthly_spent
             
    FROM transactions_info t
    JOIN customer_info c ON t.ID_client = c.ID_client
    GROUP BY month, c.gender
) AS gender_summary
ORDER BY month, gender;


/*возрастные группы клиентов с шагом 10 лет и отдельно клиентов, у которых нет данной информации, 
с параметрами сумма и количество операций за весь период, и поквартально - средние показатели и %*/
WITH total_operations AS (
	-- агрег данных по каждому клиенту
    -- вычисл общ суммы расходов и кол-во опер-й и опред-ние возр группы
    SELECT c.ID_client,
        c.Age,
        ROUND(SUM(t.Sum_payment), 2) AS total_sum, 
        COUNT(*) AS total_count, 
        CASE
            WHEN c.Age BETWEEN 0 AND 9 THEN '0-9'
            WHEN c.Age BETWEEN 10 AND 19 THEN '10-19'
            WHEN c.Age BETWEEN 20 AND 29 THEN '20-29'
            WHEN c.Age BETWEEN 30 AND 39 THEN '30-39'
            WHEN c.Age BETWEEN 40 AND 49 THEN '40-49'
            WHEN c.Age BETWEEN 50 AND 59 THEN '50-59'
            WHEN c.Age BETWEEN 60 AND 69 THEN '60-69'
            WHEN c.Age BETWEEN 70 AND 79 THEN '70-79'
            WHEN c.Age BETWEEN 80 AND 89 THEN '80-89'
            WHEN c.Age BETWEEN 90 AND 99 THEN '90-99'
            ELSE '100+'
        END AS age_group
    FROM customer_info c
    JOIN transactions_info t ON c.Id_client = t.ID_client 
    GROUP BY c.ID_client, c.Age 
),
age_groups AS (
	-- агрег данных по возр группе
    -- суммируем общ расходы и кол-во опер-й по возр группам
    SELECT age_group,
        ROUND(SUM(total_sum),2) AS total_sum, 
        SUM(total_count) AS total_count 
    FROM total_operations
    GROUP BY age_group
),
quarterly_operations AS (
	-- агрег по кварталам
    -- вычис общ сумму расходов и кол-во опер-й по возр группам
    SELECT DATE_FORMAT(STR_TO_DATE(t.date_new, '%d/%m/%Y'), '%Y-%m') AS quarter,
		SUM(t.Sum_payment) AS quarterly_sum, 
        COUNT(*) AS quarterly_count,
        CASE
            WHEN c.Age BETWEEN 0 AND 9 THEN '0-9'
            WHEN c.Age BETWEEN 10 AND 19 THEN '10-19'
            WHEN c.Age BETWEEN 20 AND 29 THEN '20-29'
            WHEN c.Age BETWEEN 30 AND 39 THEN '30-39'
            WHEN c.Age BETWEEN 40 AND 49 THEN '40-49'
            WHEN c.Age BETWEEN 50 AND 59 THEN '50-59'
            WHEN c.Age BETWEEN 60 AND 69 THEN '60-69'
            WHEN c.Age BETWEEN 70 AND 79 THEN '70-79'
            WHEN c.Age BETWEEN 80 AND 89 THEN '80-89'
            WHEN c.Age BETWEEN 90 AND 99 THEN '90-99'
            ELSE '100+'
        END AS age_group
    FROM transactions_info t
    JOIN customer_info c ON t.ID_client = c.Id_client
    GROUP BY quarter, age_group
)
SELECT ag.age_group,
    ag.total_sum,
    ag.total_count,
    ROUND(AVG(q.quarterly_sum),2) AS avg_quarterly_sum, 
    ROUND(AVG(q.quarterly_count),2) AS avg_quarterly_count, 
    ROUND(SUM(q.quarterly_sum) / NULLIF(SUM(ag.total_sum), 0) * 100, 2) AS percentage_sum, 
    ROUND(SUM(q.quarterly_count) / NULLIF(SUM(ag.total_count), 0) * 100, 2) AS percentage_count 
FROM age_groups ag
LEFT JOIN quarterly_operations q ON ag.age_group = q.age_group 
GROUP BY ag.age_group 
ORDER BY ag.age_group;
