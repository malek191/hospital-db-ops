-- Hospital Database Queries
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;

-- Query 3a: Patient Appointment History (P1001)
SELECT 
    a.Appointment_ID,
    a.Appointment_Date,
    a.Appointment_Time,
    a.Department,
    a.Status,
    d.Full_Name AS Doctor_Name
FROM 
    APPOINTMENT a
JOIN 
    DOCTOR d ON a.Doctor_ID = d.Doctor_ID
WHERE 
    a.Patient_ID = 'P1001'
ORDER BY 
    a.Appointment_Date, a.Appointment_Time;

-- Query 3b: Patients with Outstanding Bills
SELECT 
    p.Patient_ID,
    p.Full_Name,
    SUM(b.Amount_Charged - b.Amount_Paid) AS Total_Outstanding
FROM 
    PATIENT p
JOIN 
    BILLING b ON p.Patient_ID = b.Patient_ID
WHERE 
    b.Payment_Status = 'Pending'
GROUP BY 
    p.Patient_ID, p.Full_Name
HAVING 
    Total_Outstanding > 0;

-- Query 3c: Pending Lab Tests Before 2025-06-20
SELECT 
    Lab_Order_ID,
    Patient_ID,
    Test_Type,
    Scheduled_Date
FROM 
    LABTEST
WHERE 
    Result = 'Pending'
    AND Scheduled_Date < '2025-06-20';

-- Query 3d: Prescriptions (June 15-25, 2025)
SELECT 
    pr.Prescription_ID,
    pr.Patient_ID,
    d.Full_Name AS Doctor_Name,
    pr.Medication_Name,
    pr.Dosage,
    pr.Date_Issued
FROM 
    PRESCRIPTION pr
JOIN 
    DOCTOR d ON pr.Doctor_ID = d.Doctor_ID
WHERE 
    pr.Date_Issued BETWEEN '2025-06-15' AND '2025-06-25'
ORDER BY 
    pr.Date_Issued;

-- Query 3e: Doctor Appointment Stats
SELECT 
    d.Doctor_ID,
    d.Full_Name,
    COUNT(a.Appointment_ID) AS Total_Appointments,
    SUM(CASE WHEN a.Status = 'Completed' THEN 1 ELSE 0 END) AS Completed_Appointments
FROM 
    DOCTOR d
LEFT JOIN 
    APPOINTMENT a ON d.Doctor_ID = a.Doctor_ID
GROUP BY 
    d.Doctor_ID, d.Full_Name
ORDER BY 
    Total_Appointments DESC;