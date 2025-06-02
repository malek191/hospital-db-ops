import mysql.connector
from mysql.connector import Error
from datetime import datetime

def connect_db():
    try:
        conn = mysql.connector.connect(
            host='localhost', # ssh tunnel: ssh -L 3306:localhost:3306 mfahmy1@130.85.121.27
            user='mfahmy1', # change
            password='mfahmy1cmsc461',
            database='mfahmy1',
            autocommit=False # !!
        )
        return conn
    except Error as e:
        print(f"\n[!] Connection failed: {e}")
        return None

def validate_date(date_str):
    try:
        datetime.strptime(date_str, '%Y-%m-%d')
        return True
    except ValueError:
        print("\n[!] Invalid date format. Use YYYY-MM-DD")
        return False

def validate_time(time_str):
    try:
        datetime.strptime(time_str, '%H:%M:%S')
        return True
    except ValueError:
        print("\n[!] Invalid time format. Use HH:MM:SS")
        return False

def book_appointment():
    conn = connect_db()
    if not conn:
        return
    
    try:
        print("\n--- Book New Appointment ---")
        patient_id = input("Patient ID: ").strip()
        doctor_id = input("Doctor ID: ").strip()
        appt_date = input("Date (YYYY-MM-DD): ").strip()
        appt_time = input("Time (HH:MM:SS): ").strip()
        department = input("Department: ").strip()

        if not all([patient_id, doctor_id, appt_date, appt_time, department]):
            print("\n[!] All fields are required")
            return

        if not validate_date(appt_date) or not validate_time(appt_time):
            return

        with conn.cursor() as cursor:
            args = [patient_id, doctor_id, appt_date, appt_time, department, 0]
            cursor.callproc("BookAppointment", args)
            status = args[-1]
            
            if status == 0:
                print("\n[✓] Appointment booked successfully!")
            elif status == -1:
                print("\n[!] Failed: Patient has conflicting appointment")
            elif status == -2:
                print("\n[!] Failed: Doctor is unavailable")
            
            conn.commit()
            
    except Error as e:
        print(f"\n[!] Database error: {e}")
        conn.rollback()
    finally:
        conn.close()

def update_lab_result():
    conn = connect_db()
    if not conn:
        return
    
    try:
        print("\n--- Update Lab Result ---")
        lab_id = input("Lab Order ID: ").strip()
        new_result = input("New Result: ").strip()

        if not lab_id or not new_result:
            print("\n[!] Both fields are required")
            return

        with conn.cursor() as cursor:
            conn.start_transaction()
            cursor.execute(
                "UPDATE LabTest SET Result = %s WHERE Lab_Order_ID = %s",
                (new_result, lab_id)
            )
            
            if cursor.rowcount == 0:
                print("\n[!] No records updated - check Lab Order ID")
                conn.rollback()
            else:
                conn.commit()
                print("\n[✓] Lab result updated successfully")
                
    except Error as e:
        print(f"\n[!] Database error: {e}")
        conn.rollback()
    finally:
        conn.close()

def process_billing_payment():
    conn = connect_db()
    if not conn:
        return
    
    try:
        print("\n--- Process Payment ---")
        bill_id = input("Bill ID: ").strip()
        
        try:
            payment = float(input("Payment Amount: ").strip())
            if payment <= 0:
                raise ValueError("Amount must be positive")
        except ValueError as e:
            print(f"\n[!] Invalid amount: {e}")
            return

        with conn.cursor() as cursor:
            conn.start_transaction()
            cursor.execute(
                "SELECT Amount_Charged, Amount_Paid FROM Billing WHERE Bill_ID = %s",
                (bill_id,))
            row = cursor.fetchone()
            
            if not row:
                print("\n[!] Bill not found")
                conn.rollback()
                return
                
            charged, paid = row
            new_paid = paid + payment
            status = "Paid" if new_paid >= charged else "Pending"
            
            cursor.execute(
                "UPDATE Billing SET Amount_Paid = %s, Payment_Status = %s WHERE Bill_ID = %s",
                (new_paid, status, bill_id))
            
            conn.commit()
            print(f"\n[✓] Payment processed. New status: {status}")
            
    except Error as e:
        print(f"\n[!] Database error: {e}")
        conn.rollback()
    finally:
        conn.close()

def generate_patient_report():
    conn = connect_db()
    if not conn:
        return
    
    try:
        patient_id = input("\nEnter Patient ID: ").strip()
        if not patient_id:
            print("\n[!] Patient ID is required")
            return

        with conn.cursor(dictionary=True) as cursor:
            print("\n=== Patient Report ===")
            
            cursor.execute("""
                SELECT Appointment_Date, Appointment_Time, Department, Status 
                FROM Appointment 
                WHERE Patient_ID = %s
                ORDER BY Appointment_Date DESC
                """, (patient_id,))
            
            print("\n[ Appointments ]")
            for appt in cursor.fetchall():
                print(f"{appt['Appointment_Date']} {appt['Appointment_Time']} | "
                      f"{appt['Department']} | {appt['Status']}")

            cursor.execute("""
                SELECT Test_Type, Scheduled_Date, Result 
                FROM LabTest 
                WHERE Patient_ID = %s
                ORDER BY Scheduled_Date DESC
                """, (patient_id,))
            
            print("\n[ Lab Tests ]")
            for test in cursor.fetchall():
                print(f"{test['Test_Type']} | {test['Scheduled_Date']} | {test['Result']}")

            cursor.execute("""
                SELECT Service_Type, Amount_Charged, Amount_Paid, Payment_Status
                FROM Billing 
                WHERE Patient_ID = %s
                ORDER BY Service_Date DESC
                """, (patient_id,))
            
            print("\n[ Billing Summary ]")
            for bill in cursor.fetchall():
                balance = bill['Amount_Charged'] - bill['Amount_Paid']
                print(f"{bill['Service_Type']} | Charged: {bill['Amount_Charged']} | "
                      f"Paid: {bill['Amount_Paid']} | Balance: {balance} | "
                      f"Status: {bill['Payment_Status']}")
                
    except Error as e:
        print(f"\n[!] Database error: {e}")
    finally:
        conn.close()

def main():
    while True:
        print("\n" + "="*40)
        print("Hospital Management System")
        print("="*40)
        print("1. Book Appointment")
        print("2. Update Lab Test Result")
        print("3. Process Billing Payment")
        print("4. Generate Patient Report")
        print("5. Exit")
        
        choice = input("\nSelect operation (1-5): ").strip()
        
        if choice == '1':
            book_appointment()
        elif choice == '2':
            update_lab_result()
        elif choice == '3':
            process_billing_payment()
        elif choice == '4':
            generate_patient_report()
        elif choice == '5':
            print("\n[✓] Exiting system...")
            break
        else:
            print("\n[!] Invalid choice - please enter 1-5")

if __name__ == "__main__":
    main()