-- =====================================================
-- HOTEL RESERVATION & MANAGEMENT SYSTEM
-- Student: Ranjodh Singh (UID: 25BCD10160)
-- =====================================================

DROP DATABASE IF EXISTS hotel_db;
CREATE DATABASE hotel_db;
USE hotel_db;

-- ---------- TABLES ----------

CREATE TABLE room_types (
  type_id     INT AUTO_INCREMENT PRIMARY KEY,
  type_name   VARCHAR(50) NOT NULL UNIQUE,
  description TEXT,
  base_price  DECIMAL(10,2) NOT NULL CHECK (base_price > 0),
  max_occupancy INT NOT NULL DEFAULT 2
);

CREATE TABLE rooms (
  room_id     INT AUTO_INCREMENT PRIMARY KEY,
  room_number VARCHAR(10) NOT NULL UNIQUE,
  type_id     INT NOT NULL,
  floor       INT,
  status      ENUM('AVAILABLE','OCCUPIED','MAINTENANCE','RESERVED') DEFAULT 'AVAILABLE',
  FOREIGN KEY (type_id) REFERENCES room_types(type_id)
);

CREATE TABLE guests (
  guest_id    INT AUTO_INCREMENT PRIMARY KEY,
  first_name  VARCHAR(50) NOT NULL,
  last_name   VARCHAR(50) NOT NULL,
  email       VARCHAR(100) UNIQUE,
  phone       VARCHAR(20) NOT NULL,
  id_proof    VARCHAR(50),
  address     VARCHAR(255),
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE staff (
  staff_id    INT AUTO_INCREMENT PRIMARY KEY,
  first_name  VARCHAR(50) NOT NULL,
  last_name   VARCHAR(50) NOT NULL,
  role        ENUM('RECEPTIONIST','MANAGER','HOUSEKEEPING','ACCOUNTANT') NOT NULL,
  phone       VARCHAR(20),
  email       VARCHAR(100) UNIQUE,
  hire_date   DATE DEFAULT (CURRENT_DATE)
);

CREATE TABLE reservations (
  reservation_id INT AUTO_INCREMENT PRIMARY KEY,
  guest_id       INT NOT NULL,
  room_id        INT NOT NULL,
  check_in_date  DATE NOT NULL,
  check_out_date DATE NOT NULL,
  adults         INT DEFAULT 1,
  children       INT DEFAULT 0,
  status         ENUM('BOOKED','CHECKED_IN','CHECKED_OUT','CANCELLED') DEFAULT 'BOOKED',
  booked_by      INT,
  booking_date   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  special_requests TEXT,
  FOREIGN KEY (guest_id) REFERENCES guests(guest_id),
  FOREIGN KEY (room_id)  REFERENCES rooms(room_id),
  FOREIGN KEY (booked_by) REFERENCES staff(staff_id),
  CHECK (check_out_date > check_in_date)
);

CREATE TABLE payments (
  payment_id     INT AUTO_INCREMENT PRIMARY KEY,
  reservation_id INT NOT NULL,
  amount         DECIMAL(12,2) NOT NULL,
  payment_date   DATETIME DEFAULT CURRENT_TIMESTAMP,
  method         ENUM('CASH','CARD','UPI','NETBANKING') NOT NULL,
  status         ENUM('SUCCESS','PENDING','FAILED','REFUNDED') DEFAULT 'SUCCESS',
  transaction_ref VARCHAR(100),
  FOREIGN KEY (reservation_id) REFERENCES reservations(reservation_id)
);

CREATE TABLE services (
  service_id   INT AUTO_INCREMENT PRIMARY KEY,
  service_name VARCHAR(100) NOT NULL,
  price        DECIMAL(8,2) NOT NULL CHECK (price >= 0),
  description  TEXT
);

CREATE TABLE reservation_services (
  id             INT AUTO_INCREMENT PRIMARY KEY,
  reservation_id INT NOT NULL,
  service_id     INT NOT NULL,
  quantity       INT DEFAULT 1,
  service_date   DATE DEFAULT (CURRENT_DATE),
  FOREIGN KEY (reservation_id) REFERENCES reservations(reservation_id) ON DELETE CASCADE,
  FOREIGN KEY (service_id)     REFERENCES services(service_id)
);

-- ---------- TRIGGERS ----------

DELIMITER $$

-- When a guest checks in → mark room as OCCUPIED
CREATE TRIGGER trg_checkin_room
AFTER UPDATE ON reservations
FOR EACH ROW
BEGIN
  IF NEW.status = 'CHECKED_IN' AND OLD.status != 'CHECKED_IN' THEN
    UPDATE rooms SET status = 'OCCUPIED' WHERE room_id = NEW.room_id;
  END IF;
END$$

-- When a guest checks out → mark room as AVAILABLE
CREATE TRIGGER trg_checkout_room
AFTER UPDATE ON reservations
FOR EACH ROW
BEGIN
  IF NEW.status = 'CHECKED_OUT' AND OLD.status != 'CHECKED_OUT' THEN
    UPDATE rooms SET status = 'AVAILABLE' WHERE room_id = NEW.room_id;
  END IF;
END$$

-- Prevent booking an already occupied/maintenance room
CREATE TRIGGER trg_prevent_double_booking
BEFORE INSERT ON reservations
FOR EACH ROW
BEGIN
  DECLARE room_stat VARCHAR(20);
  SELECT status INTO room_stat FROM rooms WHERE room_id = NEW.room_id;
  
  IF room_stat IN ('OCCUPIED', 'MAINTENANCE') THEN
    SIGNAL SQLSTATE '45000' 
    SET MESSAGE_TEXT = 'Room is not available for booking';
  END IF;
END$$

DELIMITER ;

-- ---------- VIEWS ----------

CREATE VIEW v_available_rooms AS
SELECT r.room_id, r.room_number, rt.type_name, rt.base_price, rt.max_occupancy, r.floor
FROM rooms r
JOIN room_types rt ON r.type_id = rt.type_id
WHERE r.status = 'AVAILABLE';

CREATE VIEW v_current_guests AS
SELECT res.reservation_id, 
       CONCAT(g.first_name, ' ', g.last_name) AS guest_name,
       g.phone, r.room_number, rt.type_name,
       res.check_in_date, res.check_out_date
FROM reservations res
JOIN guests g ON res.guest_id = g.guest_id
JOIN rooms r ON res.room_id = r.room_id
JOIN room_types rt ON r.type_id = rt.type_id
WHERE res.status = 'CHECKED_IN';

CREATE VIEW v_revenue_summary AS
SELECT DATE(p.payment_date) AS payment_day,
       COUNT(*) AS total_transactions,
       SUM(p.amount) AS total_revenue
FROM payments p
WHERE p.status = 'SUCCESS'
GROUP BY DATE(p.payment_date);

-- ---------- SAMPLE DATA ----------

INSERT INTO room_types (type_name, description, base_price, max_occupancy) VALUES
('Standard', 'Basic room with double bed', 2500.00, 2),
('Deluxe', 'Spacious room with city view', 4500.00, 3),
('Suite', 'Luxury suite with living area', 8500.00, 4),
('Executive', 'Business class room', 6000.00, 2);

INSERT INTO rooms (room_number, type_id, floor, status) VALUES
('101', 1, 1, 'AVAILABLE'),
('102', 1, 1, 'AVAILABLE'),
('201', 2, 2, 'AVAILABLE'),
('202', 2, 2, 'AVAILABLE'),
('301', 3, 3, 'AVAILABLE'),
('302', 3, 3, 'MAINTENANCE'),
('401', 4, 4, 'AVAILABLE');

INSERT INTO guests (first_name, last_name, email, phone, id_proof) VALUES
('Aarav', 'Mehta', 'aarav@mail.com', '9876543210', 'Aadhaar-XXXX'),
('Priya', 'Sharma', 'priya@mail.com', '9876501234', 'Passport-YY123'),
('Rohan', 'Verma', 'rohan@mail.com', '9988776655', 'DL-PB1234'),
('Sneha', 'Kapoor', 'sneha@mail.com', '9123456789', 'Aadhaar-ZZZZ');

INSERT INTO staff (first_name, last_name, role, phone, email) VALUES
('Karan', 'Singh', 'RECEPTIONIST', '9000011111', 'karan@hotel.com'),
('Neha', 'Gupta', 'MANAGER', '9000022222', 'neha@hotel.com'),
('Amit', 'Kumar', 'HOUSEKEEPING', '9000033333', 'amit@hotel.com');

INSERT INTO services (service_name, price, description) VALUES
('Breakfast', 400.00, 'Continental breakfast'),
('Laundry', 300.00, 'Per load'),
('Airport Pickup', 1200.00, 'One way'),
('Extra Bed', 800.00, 'Additional bed');

INSERT INTO reservations (guest_id, room_id, check_in_date, check_out_date, adults, status, booked_by) VALUES
(1, 1, '2025-11-10', '2025-11-13', 2, 'CHECKED_IN', 1),
(2, 3, '2025-11-12', '2025-11-15', 2, 'BOOKED', 1),
(3, 5, '2025-11-05', '2025-11-08', 3, 'CHECKED_OUT', 2);

INSERT INTO payments (reservation_id, amount, method, status) VALUES
(1, 7500.00, 'UPI', 'SUCCESS'),
(3, 25500.00, 'CARD', 'SUCCESS');

INSERT INTO reservation_services (reservation_id, service_id, quantity) VALUES
(1, 1, 2),
(1, 2, 1);

-- ---------- USEFUL QUERIES ----------

-- 1. Available rooms
-- SELECT * FROM v_available_rooms;

-- 2. Currently staying guests
-- SELECT * FROM v_current_guests;

-- 3. Total revenue
-- SELECT SUM(amount) AS total_revenue FROM payments WHERE status = 'SUCCESS';

-- 4. Most popular room type
-- SELECT rt.type_name, COUNT(*) AS times_booked
-- FROM reservations res
-- JOIN rooms r ON res.room_id = r.room_id
-- JOIN room_types rt ON r.type_id = rt.type_id
-- GROUP BY rt.type_name
-- ORDER BY times_booked DESC;
