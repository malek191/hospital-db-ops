-- Hospital Database Stored Procedures, Functions, and Triggers
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;

-- =============================================
-- PART A: Procedure BookAppointment (FIXED VERSION)
-- =============================================
DELIMITER //

DROP PROCEDURE IF EXISTS BookAppointment//
CREATE PROCEDURE BookAppointment(
    IN p_patient_id VARCHAR(10),
    IN p_doctor_id VARCHAR(10),
    IN p_appt_date DATE,
    IN p_appt_time TIME,
    IN p_department VARCHAR(50),
    OUT p_status INT
)
proc: BEGIN
    DECLARE conflict_exists INT DEFAULT 0;
    DECLARE appt_id VARCHAR(10);
    DECLARE new_bill_id VARCHAR(10);

    -- Check patient availability (30-minute window)
    SELECT COUNT(*) INTO conflict_exists
    FROM APPOINTMENT
    WHERE Patient_ID = p_patient_id
    AND Appointment_Date = p_appt_date
    AND ABS(TIMESTAMPDIFF(MINUTE,
                         CONCAT(Appointment_Date, ' ', Appointment_Time),
                         CONCAT(p_appt_date, ' ', p_appt_time))) < 30;

    -- Check doctor availability if patient is available
    IF conflict_exists = 0 THEN
        SELECT COUNT(*) INTO conflict_exists
        FROM APPOINTMENT
        WHERE Doctor_ID = p_doctor_id
        AND Appointment_Date = p_appt_date
        AND ABS(TIMESTAMPDIFF(MINUTE,
                            CONCAT(Appointment_Date, ' ', Appointment_Time),
                            CONCAT(p_appt_date, ' ', p_appt_time))) < 30;
    END IF;

    -- Handle conflicts
    IF conflict_exists > 0 THEN
        SET p_status = -1;
        LEAVE proc;
    END IF;

    -- Generate IDs
    SELECT CONCAT('A', LPAD(COALESCE(MAX(SUBSTRING(Appointment_ID, 2)), 0) + 1, 4, '0'))
    INTO appt_id FROM APPOINTMENT;
    
    SELECT CONCAT('B', LPAD(COALESCE(MAX(SUBSTRING(Bill_ID, 2)), 0) + 1, 4, '0'))
    INTO new_bill_id FROM BILLING;

    -- Create records
    START TRANSACTION;
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

    INSERT INTO BILLING (
        Bill_ID,
        Patient_ID,
        Service_Type,
        Service_Date,
        Amount_Charged,
        Amount_Paid,
        Payment_Date,
        Payment_Status,
        version
    ) VALUES (
        new_bill_id,
        p_patient_id,
        CONCAT(p_department, ' Consultation'),
        p_appt_date,
        200.00,
        0.00,
        NULL,
        'Pending',
        1
    );
    COMMIT;

    SET p_status = 0;
END //

DELIMITER ;

-- =============================================
-- PART B: Calculate Outstanding Bill Function
-- =============================================
DELIMITER //

CREATE FUNCTION CalculateOutstandingBill(in_Patient_ID VARCHAR(10))
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    DECLARE total_outstanding DECIMAL(10,2);

    SELECT SUM(Amount_Charged - Amount_Paid)
    INTO total_outstanding
    FROM Billing
    WHERE Patient_ID = in_Patient_ID AND Payment_Status = 'Pending';

    RETURN IFNULL(total_outstanding, 0.00);
END //

DELIMITER ;

-- =============================================
-- PART C: Triggers for Billing Table
-- =============================================
DELIMITER //

DROP TRIGGER IF EXISTS check_billing_amounts//
CREATE TRIGGER check_billing_amounts
BEFORE INSERT ON Billing
FOR EACH ROW
BEGIN
    IF NEW.Amount_Charged < 0 OR NEW.Amount_Paid < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Negative billing amounts are not allowed.';
    END IF;
END //

DROP TRIGGER IF EXISTS check_billing_amounts_update//
CREATE TRIGGER check_billing_amounts_update
BEFORE UPDATE ON Billing
FOR EACH ROW
BEGIN
    IF NEW.Amount_Charged < 0 OR NEW.Amount_Paid < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Negative billing amounts are not allowed.';
    END IF;
END //

DELIMITER ;

-- =============================================
-- PART D: Trigger for Appointment Table
-- =============================================
DELIMITER //

DROP TRIGGER IF EXISTS check_appointment_date//
CREATE TRIGGER check_appointment_date
BEFORE INSERT ON Appointment
FOR EACH ROW
BEGIN
    IF NEW.Appointment_Date < CURDATE() THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot schedule an appointment in the past.';
    END IF;
END //

DELIMITER ;