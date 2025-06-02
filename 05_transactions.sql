-- Hospital Database Queries Transactions
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;

-- =============================================
-- First add the version columns if they don't exist
-- =============================================
SET @dbname = DATABASE();
SET @tablename = 'BILLING';
SET @prepared = (SELECT IF(
  EXISTS(
    SELECT * FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = @dbname
    AND TABLE_NAME = @tablename
    AND COLUMN_NAME = 'version'
  ),
  'SELECT 1',
  CONCAT('ALTER TABLE ', @tablename, ' ADD COLUMN version INT DEFAULT 1;')
));
PREPARE alterIfNotExists FROM @prepared;
EXECUTE alterIfNotExists;
DEALLOCATE PREPARE alterIfNotExists;

SET @tablename = 'APPOINTMENT';
SET @prepared = (SELECT IF(
  EXISTS(
    SELECT * FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = @dbname
    AND TABLE_NAME = @tablename
    AND COLUMN_NAME = 'version'
  ),
  'SELECT 1',
  CONCAT('ALTER TABLE ', @tablename, ' ADD COLUMN version INT DEFAULT 1;')
));
PREPARE alterIfNotExists FROM @prepared;
EXECUTE alterIfNotExists;
DEALLOCATE PREPARE alterIfNotExists;

-- =============================================
-- PART A: Appointment Booking Program
-- =============================================
DELIMITER //
DROP PROCEDURE IF EXISTS BookAppointment//
CREATE PROCEDURE BookAppointment(
    IN p_patient_id VARCHAR(10),
    IN p_doctor_id VARCHAR(10),
    IN p_appt_date DATE,
    IN p_appt_time TIME,
    IN p_department VARCHAR(50))
BEGIN
    DECLARE conflict_exists INT DEFAULT 0;
    DECLARE appt_id VARCHAR(10);
    DECLARE new_bill_id VARCHAR(10);

    -- Generate new IDs
    SELECT CONCAT('A', LPAD(COALESCE(MAX(SUBSTRING(Appointment_ID, 2)), 0) + 1, 4, '0'))
    INTO appt_id FROM APPOINTMENT;

    SELECT CONCAT('B', LPAD(COALESCE(MAX(SUBSTRING(Bill_ID, 2)), 0) + 1, 4, '0'))
    INTO new_bill_id FROM BILLING;

    START TRANSACTION;

    -- Check for patient availability (30-minute appointments)
    SELECT COUNT(*) INTO conflict_exists
    FROM APPOINTMENT
    WHERE Patient_ID = p_patient_id
    AND Appointment_Date = p_appt_date
    AND ABS(TIMESTAMPDIFF(MINUTE, 
                          CONCAT(Appointment_Date, ' ', Appointment_Time),
                          CONCAT(p_appt_date, ' ', p_appt_time))) < 30;

    -- Check for doctor availability if patient is available
    IF conflict_exists = 0 THEN
        SELECT COUNT(*) INTO conflict_exists
        FROM APPOINTMENT
        WHERE Doctor_ID = p_doctor_id
        AND Appointment_Date = p_appt_date
        AND ABS(TIMESTAMPDIFF(MINUTE, 
                              CONCAT(Appointment_Date, ' ', Appointment_Time),
                              CONCAT(p_appt_date, ' ', p_appt_time))) < 30;
    END IF;

    -- If no conflicts, proceed after delay
    IF conflict_exists = 0 THEN
        DO SLEEP(5);  -- Simulate processing delay

        -- Insert the new appointment
        INSERT INTO APPOINTMENT (
            Appointment_ID,
            Patient_ID,
            Doctor_ID,
            Department,
            Appointment_Date,
            Appointment_Time,
            Status,
            version
        ) VALUES (
            appt_id,
            p_patient_id,
            p_doctor_id,
            p_department,
            p_appt_date,
            p_appt_time,
            'Scheduled',
            1
        );

        -- Create associated billing record
        INSERT INTO BILLING (
            Bill_ID,
            Patient_ID,
            Service_Type,
            Service_Date,
            Amount_Charged,
            Amount_Paid,
            Payment_Status,
            version
        ) VALUES (
            new_bill_id,
            p_patient_id,
            CONCAT(p_department, ' Consultation'),
            p_appt_date,
            200.00,  -- Default consultation fee
            0.00,
            'Pending',
            1
        );

        COMMIT;
        SELECT CONCAT('Appointment booked successfully. ID: ', appt_id) AS Result;
    ELSE
        ROLLBACK;
        SELECT 'Booking failed - time slot not available' AS Result;
    END IF;
END //
DELIMITER ;

-- =============================================
-- PART C: Concurrent Billing Transactions
-- =============================================

-- Transaction T1: Payment Processing
DELIMITER //
DROP PROCEDURE IF EXISTS ProcessPayment//
CREATE PROCEDURE ProcessPayment(
    IN p_bill_id VARCHAR(10),
    IN p_amount DECIMAL(10,2))
BEGIN
    DECLARE current_version INT;
    DECLARE rows_updated INT;

    START TRANSACTION;

    -- Check if version column exists
    IF EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE TABLE_NAME = 'BILLING' AND COLUMN_NAME = 'version'
    ) THEN
        -- With version control
        SELECT version INTO current_version FROM BILLING 
        WHERE Bill_ID = p_bill_id FOR UPDATE;

        DO SLEEP(2);

        UPDATE BILLING 
        SET 
            Amount_Paid = Amount_Paid + p_amount,
            Payment_Status = CASE 
                                WHEN Amount_Charged <= (Amount_Paid + p_amount) THEN 'Paid' 
                                ELSE 'Pending' 
                             END,
            version = version + 1
        WHERE 
            Bill_ID = p_bill_id
            AND version = current_version;
    ELSE
        -- Fallback without version control
        DO SLEEP(2);

        UPDATE BILLING 
        SET 
            Amount_Paid = Amount_Paid + p_amount,
            Payment_Status = CASE 
                                WHEN Amount_Charged <= (Amount_Paid + p_amount) THEN 'Paid' 
                                ELSE 'Pending' 
                             END
        WHERE 
            Bill_ID = p_bill_id;
    END IF;

    SET rows_updated = ROW_COUNT();

    IF rows_updated = 1 THEN
        COMMIT;
        SELECT 'Payment processed successfully' AS Result;
    ELSE
        ROLLBACK;
        SELECT 'Payment failed - record was modified by another transaction' AS Result;
    END IF;
END //
DELIMITER ;

-- =============================================
-- PART D: Appointment Status Change Transactions
-- =============================================

-- Transaction T3: Complete Appointment
DELIMITER //
DROP PROCEDURE IF EXISTS CompleteAppointment//
CREATE PROCEDURE CompleteAppointment(IN p_appointment_id VARCHAR(10))
BEGIN
    DECLARE v_patient_id VARCHAR(10);
    DECLARE v_service_date DATE;

    START TRANSACTION;

    -- Get appointment details
    SELECT Patient_ID, Appointment_Date 
    INTO v_patient_id, v_service_date
    FROM APPOINTMENT 
    WHERE Appointment_ID = p_appointment_id FOR UPDATE;

    DO SLEEP(2);

    -- Update appointment status
    UPDATE APPOINTMENT 
    SET Status = 'Completed'
    WHERE Appointment_ID = p_appointment_id;

    -- Update billing status
    UPDATE BILLING 
    SET Payment_Status = 'Processing'
    WHERE Patient_ID = v_patient_id 
    AND Service_Date = v_service_date;

    COMMIT;
    SELECT 'Appointment marked as completed' AS Result;
END //
DELIMITER ;

-- Transaction T4: Cancel Appointment
DELIMITER //
DROP PROCEDURE IF EXISTS CancelAppointment//
CREATE PROCEDURE CancelAppointment(IN p_appointment_id VARCHAR(10))
BEGIN
    DECLARE v_patient_id VARCHAR(10);
    DECLARE v_service_date DATE;

    START TRANSACTION;

    -- Get appointment details
    SELECT Patient_ID, Appointment_Date 
    INTO v_patient_id, v_service_date
    FROM APPOINTMENT 
    WHERE Appointment_ID = p_appointment_id FOR UPDATE;

    DO SLEEP(2);

    -- Update billing first
    UPDATE BILLING 
    SET Payment_Status = 'Void'
    WHERE Patient_ID = v_patient_id 
    AND Service_Date = v_service_date;

    -- Then update appointment
    UPDATE APPOINTMENT 
    SET Status = 'Canceled'
    WHERE Appointment_ID = p_appointment_id;

    COMMIT;
    SELECT 'Appointment canceled' AS Result;
END //
DELIMITER ;

-- =============================================
-- FIXED CLEANUP SECTION
-- =============================================

/*
-- Reset appointment A3001
UPDATE APPOINTMENT SET 
    Status = 'Scheduled'
WHERE Appointment_ID = 'A3001';

-- Reset bill B6001
UPDATE BILLING SET 
    Amount_Paid = 0,
    Payment_Status = 'Pending'
WHERE Bill_ID = 'B6001';

-- Remove test appointments if needed
-- DELETE FROM APPOINTMENT WHERE Appointment_ID LIKE 'A99%';
-- DELETE FROM BILLING WHERE Bill_ID LIKE 'B99%';
*/

-- =============================================
-- EXAMPLE USAGE (commented out)
-- =============================================

/*
-- Book new appointment
CALL BookAppointment('P1001', 'D2001', '2025-07-01', '14:00:00', 'Cardiology');

-- Process payment
CALL ProcessPayment('B6001', 100.00);

-- Generate report
CALL GenerateBillingReport('P1001');

-- Complete appointment
CALL CompleteAppointment('A3001');

-- Cancel appointment
CALL CancelAppointment('A3001');
*/