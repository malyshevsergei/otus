-- Create project database
CREATE DATABASE IF NOT EXISTS project_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Create application user
CREATE USER IF NOT EXISTS 'appuser'@'%' IDENTIFIED BY 'apppass';
GRANT ALL PRIVILEGES ON project_db.* TO 'appuser'@'%';
FLUSH PRIVILEGES;

-- Use the database
USE project_db;

-- Create example tables for the project
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_email (email),
    INDEX idx_username (username)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS products (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL,
    stock_quantity INT DEFAULT 0,
    category VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_category (category),
    INDEX idx_price (price)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS orders (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total_amount DECIMAL(10, 2) NOT NULL,
    status ENUM('pending', 'processing', 'shipped', 'delivered', 'cancelled') DEFAULT 'pending',
    shipping_address TEXT,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id),
    INDEX idx_status (status),
    INDEX idx_order_date (order_date)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS order_items (
    id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT,
    INDEX idx_order_id (order_id),
    INDEX idx_product_id (product_id)
) ENGINE=InnoDB;

-- Insert sample data
INSERT INTO users (username, email, password_hash) VALUES
    ('john_doe', 'john@example.com', '$2y$10$abcdefghijklmnopqrstuvwxyz'),
    ('jane_smith', 'jane@example.com', '$2y$10$zyxwvutsrqponmlkjihgfedcba'),
    ('admin', 'admin@example.com', '$2y$10$adminpasswordhash123456789');

INSERT INTO products (name, description, price, stock_quantity, category) VALUES
    ('Laptop', 'High-performance laptop', 999.99, 50, 'Electronics'),
    ('Smartphone', 'Latest model smartphone', 699.99, 100, 'Electronics'),
    ('Headphones', 'Wireless noise-cancelling headphones', 299.99, 200, 'Accessories'),
    ('Keyboard', 'Mechanical gaming keyboard', 149.99, 75, 'Accessories'),
    ('Mouse', 'Ergonomic wireless mouse', 79.99, 150, 'Accessories');

INSERT INTO orders (user_id, total_amount, status, shipping_address) VALUES
    (1, 1299.98, 'delivered', '123 Main St, City, Country'),
    (2, 699.99, 'shipped', '456 Oak Ave, Town, Country'),
    (1, 379.98, 'processing', '123 Main St, City, Country');

INSERT INTO order_items (order_id, product_id, quantity, price) VALUES
    (1, 1, 1, 999.99),
    (1, 5, 1, 299.99),
    (2, 2, 1, 699.99),
    (3, 3, 1, 299.99),
    (3, 5, 1, 79.99);

-- Show created tables
SHOW TABLES;

-- Show sample data
SELECT 'Users:' as '';
SELECT * FROM users;

SELECT 'Products:' as '';
SELECT * FROM products;

SELECT 'Orders:' as '';
SELECT * FROM orders;

SELECT 'Order Items:' as '';
SELECT * FROM order_items;
