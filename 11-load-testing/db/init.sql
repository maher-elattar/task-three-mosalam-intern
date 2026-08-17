-- Seed data for the sample API.
-- MySQL runs this file only when the database volume is created for the first time.

CREATE TABLE IF NOT EXISTS products (
  id INT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(80) NOT NULL,
  price DECIMAL(10,2) NOT NULL
);

INSERT INTO products (name, price) VALUES
  ('starter-vm', 9.99),
  ('team-cache', 14.50),
  ('managed-database', 29.00)
ON DUPLICATE KEY UPDATE name = VALUES(name), price = VALUES(price);

-- Exporter user used in the monitoring stage.
CREATE USER IF NOT EXISTS 'monitor'@'%' IDENTIFIED BY 'monitorpass';
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'monitor'@'%';
FLUSH PRIVILEGES;

