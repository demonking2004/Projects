-- -----------------------------------------
-- 💰 Project 9: Personal Finance Tracker
-- -----------------------------------------

-- Create and use database
CREATE DATABASE IF NOT EXISTS FinanceDB;
USE FinanceDB;

-- Users Table
CREATE TABLE Users (
    user_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100),
    email VARCHAR(100),
    monthly_budget DECIMAL(10,2)
);

-- Categories Table
CREATE TABLE Categories (
    category_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(50)
);

-- Income Table
CREATE TABLE Income (
    income_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT,
    amount DECIMAL(10,2),
    source VARCHAR(100),
    date DATE,
    FOREIGN KEY (user_id) REFERENCES Users(user_id)
);

-- Expenses Table
CREATE TABLE Expenses (
    expense_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT,
    amount DECIMAL(10,2),
    category_id INT,
    date DATE,
    FOREIGN KEY (user_id) REFERENCES Users(user_id),
    FOREIGN KEY (category_id) REFERENCES Categories(category_id)
);

-- Transaction Logs Table
CREATE TABLE TransactionLogs (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    action VARCHAR(100),
    amount DECIMAL(10,2),
    log_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES Users(user_id)
);

-- Trigger: Log expenses
DELIMITER $$
CREATE TRIGGER log_expense
AFTER INSERT ON Expenses
FOR EACH ROW
BEGIN
    INSERT INTO TransactionLogs (user_id, action, amount)
    VALUES (NEW.user_id, CONCAT('Expense: ', NEW.amount), NEW.amount);
END $$
DELIMITER ;

-- Trigger: Prevent overspending
DELIMITER $$
CREATE TRIGGER prevent_overspending
BEFORE INSERT ON Expenses
FOR EACH ROW
BEGIN
    DECLARE monthly_spent DECIMAL(10,2);
    DECLARE budget DECIMAL(10,2);

    SELECT monthly_budget INTO budget FROM Users WHERE user_id = NEW.user_id;
    SELECT IFNULL(SUM(amount), 0) INTO monthly_spent
    FROM Expenses
    WHERE user_id = NEW.user_id AND MONTH(date) = MONTH(NEW.date) AND YEAR(date) = YEAR(NEW.date);

    IF monthly_spent + NEW.amount > budget THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Expense exceeds monthly budget.';
    END IF;
END $$
DELIMITER ;

-- Procedure: Add Monthly Income & Adjust Budget
DELIMITER $$
CREATE PROCEDURE AddMonthlyIncome(IN uid INT, IN amount DECIMAL(10,2), IN source VARCHAR(100))
BEGIN
    INSERT INTO Income (user_id, amount, source, date)
    VALUES (uid, amount, source, CURDATE());

    UPDATE Users
    SET monthly_budget = monthly_budget + (amount * 0.2)
    WHERE user_id = uid;
END $$
DELIMITER ;

-- Procedure: Close Month Summary
DELIMITER $$
CREATE PROCEDURE CloseMonth(IN uid INT, IN closing_date DATE)
BEGIN
    DECLARE total_income DECIMAL(10,2);
    DECLARE total_expense DECIMAL(10,2);

    SELECT SUM(amount) INTO total_income
    FROM Income WHERE user_id = uid AND MONTH(date) = MONTH(closing_date) AND YEAR(date) = YEAR(closing_date);

    SELECT SUM(amount) INTO total_expense
    FROM Expenses WHERE user_id = uid AND MONTH(date) = MONTH(closing_date) AND YEAR(date) = YEAR(closing_date);

    INSERT INTO TransactionLogs (user_id, action, amount)
    VALUES (uid, CONCAT('Month Closed: Income=', total_income, ', Expense=', total_expense), 0);
END $$
DELIMITER ;

-- View: Budget Status
CREATE VIEW budget_status AS
SELECT 
    u.name,
    u.monthly_budget,
    DATE_FORMAT(e.date, '%Y-%m') AS month,
    SUM(e.amount) AS spent,
    u.monthly_budget - SUM(e.amount) AS balance_remaining
FROM Users u
JOIN Expenses e ON u.user_id = e.user_id
GROUP BY u.user_id, month;

-- View: Monthly Category-wise Expenses using CTE
WITH monthly_expenses AS (
    SELECT 
        user_id,
        category_id,
        DATE_FORMAT(date, '%Y-%m') AS month,
        SUM(amount) AS total
    FROM Expenses
    GROUP BY user_id, category_id, month
)
SELECT 
    u.name, c.name AS category, m.month, m.total
FROM monthly_expenses m
JOIN Users u ON m.user_id = u.user_id
JOIN Categories c ON m.category_id = c.category_id
ORDER BY u.name, m.month;

-- Spending Ratio Report
WITH user_monthly AS (
    SELECT user_id, DATE_FORMAT(date, '%Y-%m') AS month, SUM(amount) AS income
    FROM Income GROUP BY user_id, month
),
expense_monthly AS (
    SELECT user_id, DATE_FORMAT(date, '%Y-%m') AS month, SUM(amount) AS expense
    FROM Expenses GROUP BY user_id, month
)
SELECT 
    u.name,
    i.month,
    i.income,
    e.expense,
    ROUND(e.expense / i.income * 100, 2) AS spend_ratio_percent
FROM user_monthly i
JOIN expense_monthly e ON i.user_id = e.user_id AND i.month = e.month
JOIN Users u ON u.user_id = i.user_id;

-- -----------------------------------------------------
-- 🔢 Dummy Data for Testing
-- -----------------------------------------------------

-- Users
INSERT INTO Users (name, email, monthly_budget) VALUES
('Alice Johnson', 'alice@example.com', 20000.00),
('Bob Smith', 'bob@example.com', 15000.00),
('Charlie Lee', 'charlie@example.com', 25000.00);

-- Categories
INSERT INTO Categories (name) VALUES
('Rent'),
('Groceries'),
('Utilities'),
('Entertainment'),
('Transport'),
('Health'),
('Education');

-- Income
INSERT INTO Income (user_id, amount, source, date) VALUES
(1, 50000.00, 'Job Salary', '2025-07-01'),
(2, 40000.00, 'Freelancing', '2025-07-03'),
(3, 60000.00, 'Consulting', '2025-07-02'),
(1, 3000.00, 'Dividends', '2025-07-10'),
(2, 2500.00, 'Stock Market', '2025-07-12');

-- Expenses
INSERT INTO Expenses (user_id, amount, category_id, date) VALUES
(1, 12000.00, 1, '2025-07-05'), -- Rent
(1, 2500.00, 2, '2025-07-06'),  -- Groceries
(1, 1000.00, 3, '2025-07-07'),  -- Utilities
(1, 1500.00, 4, '2025-07-08'),  -- Entertainment
(2, 8000.00, 1, '2025-07-05'),
(2, 2000.00, 2, '2025-07-06'),
(2, 700.00, 5, '2025-07-09'),
(2, 900.00, 3, '2025-07-11'),
(3, 15000.00, 1, '2025-07-04'),
(3, 3000.00, 6, '2025-07-10'),
(3, 2000.00, 7, '2025-07-14');
