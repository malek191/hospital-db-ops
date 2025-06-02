1. ER Diagram

2. Queries:
-- Query 1: Patient Appointment History
SELECT * FROM APPOINTMENT WHERE Patient_ID = 'P1001';

-- Query 2: Outstanding Bills to help identify unpaid balances
SELECT Patient_ID, SUM(Amount_Charged - Amount_Paid) 
FROM BILLING 
WHERE Payment_Status = 'Pending' 
GROUP BY Patient_ID;

-- Query 3: Doctor Appointment Stats for planning etc
SELECT d.Doctor_ID, COUNT(a.Appointment_ID) 
FROM DOCTOR d LEFT JOIN APPOINTMENT a 
ON d.Doctor_ID = a.Doctor_ID 
GROUP BY d.Doctor_ID;



3. Transaction Scenarios:

-- Scenario A: Booking Conflict
CALL BookAppointment('P1001','D2001','2025-07-01','10:00:00','Cardiology',@status);
SELECT @status; -- Should show 0

CALL BookAppointment('P1001','D2001','2025-07-01','10:15:00','Cardiology',@status);
SELECT @status; -- Should now show -1 (fails for conflicting 30 min buffer)

-- To Verify:
SELECT * FROM APPOINTMENT WHERE Appointment_Date = '2025-07-01';

-- To Reset Data:
DELETE FROM APPOINTMENT WHERE Appointment_Date = '2025-07-01';
DELETE FROM BILLING WHERE Service_Date = '2025-07-01';



-- Scenario B: Payment Processing
START TRANSACTION;
UPDATE BILLING SET Amount_Paid = 100 WHERE Bill_ID = 'B6001';
COMMIT; -- Wait

SELECT * FROM BILLING WHERE Bill_ID = 'B6001';

-- To Reset:
UPDATE BILLING SET 
    Amount_Paid = 0.00,
    Payment_Status = 'Pending',
    Payment_Date = NULL,
    version = version + 1
WHERE Bill_ID = 'B6001';



-- Scenario C: Triggers
-- Test 1: Negative billing amount
INSERT INTO BILLING VALUES (
    'B9999',        -- Bill_ID
    'P1001',        -- Patient_ID
    'Test',         -- Service_Type
    '2025-01-01',   -- Service_Date
    -100,           -- Invalid negative amount
    0,              -- Amount_Paid
    NULL,           -- Payment_Date
    'Pending',      -- Payment_Status
    1               -- version
);

-- Test 2: Past appointment date (SHOULD FAIL)
INSERT INTO APPOINTMENT VALUES (
    'A9999',        -- Appointment_ID
    'P1001',        -- Patient_ID
    'D2001',        -- Doctor_ID
    'Cardiology',   -- Department
    '2020-01-01',   -- Invalid past date
    '10:00:00',     -- Appointment_Time
    'Scheduled',    -- Status
    1               -- version
);

-- Valid billing
INSERT INTO BILLING VALUES (
    'B9999', 'P1001', 'Test', '2025-01-01', 
    100, 0, NULL, 'Pending', 1
);

-- Valid appointment
INSERT INTO APPOINTMENT VALUES (
    'A9999', 'P1001', 'D2001', 'Cardiology',
    '2025-12-31', '10:00:00', 'Scheduled', 1
);

-- To Reset:
DELETE FROM BILLING WHERE Bill_ID = 'B9999';
DELETE FROM APPOINTMENT WHERE Appointment_ID = 'A9999';