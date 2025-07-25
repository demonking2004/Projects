-- ------------------------
-- 📚 Library Management System
-- ------------------------

CREATE DATABASE IF NOT EXISTS LibraryDB;
USE LibraryDB;

-- Authors Table
CREATE TABLE Authors (
    author_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100),
    birth_year YEAR
);

-- Books Table
CREATE TABLE Books (
    book_id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(200),
    genre VARCHAR(100),
    published_year YEAR
);

-- Members Table
CREATE TABLE Members (
    member_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100),
    join_date DATE,
    email VARCHAR(100)
);

-- BookAuthors Table (Many-to-Many)
CREATE TABLE BookAuthors (
    book_id INT,
    author_id INT,
    PRIMARY KEY (book_id, author_id),
    FOREIGN KEY (book_id) REFERENCES Books(book_id),
    FOREIGN KEY (author_id) REFERENCES Authors(author_id)
);

-- Loans Table
CREATE TABLE Loans (
    loan_id INT AUTO_INCREMENT PRIMARY KEY,
    book_id INT,
    member_id INT,
    loan_date DATE,
    due_date DATE,
    return_date DATE,
    FOREIGN KEY (book_id) REFERENCES Books(book_id),
    FOREIGN KEY (member_id) REFERENCES Members(member_id)
);

-- Insert Authors
INSERT INTO Authors (name, birth_year) VALUES
('George Orwell', 1903),
('J.K. Rowling', 1965),
('J.R.R. Tolkien', 1892),
('Agatha Christie', 1890),
('Dan Brown', 1964),
('Jane Austen', 1775);

-- Insert Books
INSERT INTO Books (title, genre, published_year) VALUES
('1984', 'Dystopian', 1949),
('Harry Potter and the Philosophers Stone', 'Fantasy', 1997),
('The Hobbit', 'Fantasy', 1937),
('Murder on the Orient Express', 'Mystery', 1934),
('The Da Vinci Code', 'Thriller', 2003),
('Pride and Prejudice', 'Romance', 1813);

-- Insert Members
INSERT INTO Members (name, join_date, email) VALUES
('Alice Johnson', '2023-01-15', 'alice@example.com'),
('Bob Smith', '2023-03-22', 'bob@example.com'),
('Charlie Davies', '2023-04-10', 'charlie@example.com'),
('Diana Patel', '2023-05-05', 'diana@example.com'),
('Edward Lin', '2023-06-01', 'edward@example.com');

-- Insert BookAuthors
INSERT INTO BookAuthors (book_id, author_id) VALUES
(1, 1),
(2, 2),
(3, 3),
(4, 4),
(5, 5),
(6, 6);

-- Insert Loans
INSERT INTO Loans (book_id, member_id, loan_date, due_date, return_date) VALUES
(1, 1, '2023-06-01', '2023-06-15', '2023-06-10'),
(2, 2, '2023-06-10', '2023-06-24', NULL),
(3, 3, '2023-07-01', '2023-07-15', NULL),
(4, 4, '2023-07-03', '2023-07-17', NULL),
(5, 5, '2023-07-05', '2023-07-19', NULL),
(6, 1, '2023-07-07', '2023-07-21', NULL);


-- Trigger: Track book returns
DELIMITER $$
CREATE TRIGGER track_return
AFTER UPDATE ON Loans
FOR EACH ROW
BEGIN
    IF OLD.return_date IS NULL AND NEW.return_date IS NOT NULL THEN
        INSERT INTO LoanAudit (loan_id, action)
        VALUES (NEW.loan_id, 'Book Returned');
    END IF;
END $$
DELIMITER ;

-- Procedure: Renew Loan
DELIMITER $$
CREATE PROCEDURE RenewLoan(IN loanId INT)
BEGIN
    DECLARE current_due DATE;
    DECLARE already_returned DATE;

    SELECT due_date, return_date INTO current_due, already_returned
    FROM Loans WHERE loan_id = loanId;

    IF already_returned IS NOT NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Book already returned.';
    ELSEIF current_due < CURDATE() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot renew overdue loan.';
    ELSE
        UPDATE Loans SET due_date = DATE_ADD(current_due, INTERVAL 7 DAY)
        WHERE loan_id = loanId;
    END IF;
END $$
DELIMITER ;

-- Function: Check if book is available
DELIMITER $$
CREATE FUNCTION IsBookAvailable(bid INT)
RETURNS BOOLEAN DETERMINISTIC
BEGIN
    DECLARE is_available BOOLEAN;
    SELECT COUNT(*) = 0 INTO is_available
    FROM Loans
    WHERE book_id = bid AND return_date IS NULL;
    RETURN is_available;
END $$
DELIMITER ;

-- Views
CREATE VIEW books_with_authors AS
SELECT b.title, GROUP_CONCAT(a.name SEPARATOR ', ') AS authors
FROM Books b
JOIN BookAuthors ba ON b.book_id = ba.book_id
JOIN Authors a ON ba.author_id = a.author_id
GROUP BY b.book_id;

CREATE VIEW overdue_loans AS
SELECT l.*, m.name AS member_name, b.title
FROM Loans l
JOIN Members m ON l.member_id = m.member_id
JOIN Books b ON l.book_id = b.book_id
WHERE l.return_date IS NULL AND l.due_date < CURDATE();

CREATE VIEW weekly_overdue_summary AS
SELECT m.name, COUNT(*) AS overdue_count, WEEK(l.due_date) AS week_number
FROM Loans l
JOIN Members m ON l.member_id = m.member_id
WHERE l.return_date IS NULL AND l.due_date < CURDATE()
GROUP BY m.name, WEEK(l.due_date);

-- Top 3 Members
SELECT m.name, COUNT(*) AS loans_count
FROM Loans l
JOIN Members m ON l.member_id = m.member_id
GROUP BY m.name
ORDER BY loans_count DESC
LIMIT 3;

-- Window Function Example
SELECT 
    member_id,
    loan_id,
    COUNT(*) OVER (PARTITION BY member_id) AS total_loans
FROM Loans;
