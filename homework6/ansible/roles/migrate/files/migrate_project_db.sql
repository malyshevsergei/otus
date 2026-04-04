-- Migration of project_db from MySQL (homework5) to PostgreSQL (homework6)
-- Original schema: users, products, orders, order_items

BEGIN;

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);

-- Products table
CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    price NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    category VARCHAR(100),
    stock_quantity INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);
CREATE INDEX IF NOT EXISTS idx_products_price ON products(price);

-- Orders table
CREATE TABLE IF NOT EXISTS orders (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    total_amount NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    shipping_address TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);

-- Order items table
CREATE TABLE IF NOT EXISTS order_items (
    id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    quantity INTEGER NOT NULL DEFAULT 1,
    price NUMERIC(10, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product_id ON order_items(product_id);

-- Sample data (same as homework5 MySQL)
INSERT INTO users (username, email, password_hash, first_name, last_name) VALUES
    ('john_doe', 'john@example.com', '$2b$12$LJ3m4ys5RfGkX7K0vQ2VXOhHhNwMjK7yR5eB3kLpNfVp6z5x9O', 'John', 'Doe'),
    ('jane_smith', 'jane@example.com', '$2b$12$9kF3mHyXvO7nQ2Bp4jY1ZOdL5wA8kR6tV3cN7xM0sG2hU4iE5W', 'Jane', 'Smith'),
    ('bob_wilson', 'bob@example.com', '$2b$12$Kp5mR8yXvO7nQ2Bp4jY1ZOdL5wA8kR6tV3cN7xM0sG2hU4iE5W', 'Bob', 'Wilson')
ON CONFLICT DO NOTHING;

INSERT INTO products (name, description, price, category, stock_quantity) VALUES
    ('Laptop Pro 15', 'High-performance laptop with 15-inch display', 1299.99, 'Electronics', 50),
    ('Wireless Mouse', 'Ergonomic wireless mouse with long battery life', 29.99, 'Accessories', 200),
    ('USB-C Hub', '7-in-1 USB-C hub with HDMI and ethernet', 49.99, 'Accessories', 150),
    ('Mechanical Keyboard', 'RGB mechanical keyboard with Cherry MX switches', 89.99, 'Accessories', 100),
    ('Monitor 27"', '4K IPS monitor with USB-C connectivity', 449.99, 'Electronics', 30)
ON CONFLICT DO NOTHING;

INSERT INTO orders (user_id, status, total_amount, shipping_address) VALUES
    (1, 'completed', 1329.98, '123 Main St, New York, NY 10001'),
    (2, 'processing', 139.98, '456 Oak Ave, Los Angeles, CA 90001'),
    (1, 'pending', 449.99, '123 Main St, New York, NY 10001')
ON CONFLICT DO NOTHING;

INSERT INTO order_items (order_id, product_id, quantity, price) VALUES
    (1, 1, 1, 1299.99),
    (1, 2, 1, 29.99),
    (2, 4, 1, 89.99),
    (2, 3, 1, 49.99),
    (3, 5, 1, 449.99)
ON CONFLICT DO NOTHING;

COMMIT;
