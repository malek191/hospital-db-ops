Team details:
	- Malek Moussa: NZ85414
	- Youssef Tafesh: MJ35774



Key Design Choices:
	1. ER Diagram Structure:
		- Used 6 core entities (Patient, Doctor, Appointment, LabTest, Prescription, Billing)
		- Established 1:N relationships between Patient and other entities
		- Implemented proper referential integrity with foreign keys

	2. Transaction Isolation:
		- Set `READ COMMITTED` isolation level to:
			• Prevent dirty reads
			• Avoid cascading rollbacks
			• Meet project requirements

	3. Schema Constraints:
		- Added NOT NULL constraints for critical fields
		- Used appropriate data types (DATE for dates, DECIMAL for monetary values)
		- Enforced referential integrity through foreign keys

	4. Concurrency Control:
		- Added version columns for optimistic locking
		- Implemented automatic version checking
		- Used FOR UPDATE locks for critical sections
		- Built fallback mechanisms for missing version columns

	5. Phase 3:  
		- Implemented dual triggers for billing (insert + update)  
		- Designed appointment booking with 3-state status codes  
		- Created self-healing schema (auto-adds version columns)  
		- Built Python CLI with atomic transaction support  



Learning Outcomes:
	- Gained practical experience in relational database design
	- Learned to implement proper transaction isolation levels
	- Developed skills in creating comprehensive ER diagrams
	- Understood the importance of data integrity constraints
	- Mastered concurrency control techniques
	- Learned to handle transaction conflicts gracefully
	- Implemented automated business rules via triggers
	- Developed stored procedures with error signaling
	- Created transactional Python-MariaDB integration



Project files & description:
	- ER_Diagram.png:             Visual representation of database schema (created with draw.io)
	- 01_schema.sql:              SQL script to create all database tables with constraints
	- 02_data.sql:                Script to populate tables with sample data
	- 03_verification.sql:        Validation queries to confirm proper implementation
	- 04_queries.sql:             Phase 2 required SQL queries (3a-3e)
	- 05_transactions.sql:        Phase 2 transaction procedures with concurrency control
        - 06_functions.sql:           Phase 3 stored procedures, functions and triggers
	- 07_TransactionalProgram.py: Phase 3 transactional operations program
	- 08_demo.sql:    	      Notes and tests for the demo
	- DemoVideo1.mp4:             1st Demo Video on the ER diagram, SQL queries, transactions, and triggers
	- DemoVideo2.mp4:             2nd Demo Video on the Transactional Program



Instructions on how to set up and run my database:
	1. MariaDB
	2. Command-line access to database server
	3. Run the files in numerical order
	4. for file 07, edit credentials (lines 8-11)



Challenges I faced and how I addressed them:
	- Setting global transaction isolation required SUPER privileges
		• Used session-level isolation in each script

	- Complex relationships between entities
		• Created detailed ER diagram first to visualize connections

	- Ensuring data integrity across multiple tables
		• Implemented foreign key constraints and proper data types

	- Handling date/time formats in SQL
		• Used standard DATE and TIME data types with ISO formats

	- Transaction conflicts in concurrent operations
		• Added version control columns and optimistic locking
		• Implemented automatic version checking in procedures

	- Missing version columns in initial implementation
		• Added automatic column creation at runtime
		• Built fallback procedures that work with/without versions

        - Implementing stored procedures
		• Modified Python program to properly handle status codes from BookAppointment  

	- Phase 3 Challenges:
		• Trigger conflict resolution:  
			- Used BEFORE INSERT/UPDATE triggers  
			- Implemented SQLSTATE 45000 for custom errors  

		• Python-MariaDB integration:  
			- Added dictionary cursors for readable results  
			- Implemented proper connection pooling  

		• Appointment validation:  
			- Added 30-minute buffer checks in BookAppointment 

		• Trigger Testing Difficulties:  
			- Needed to test negative cases without corrupting production data  
			- Implemented:  
				- Transaction-wrapped test cases with automatic rollback  
				- Dedicated test IDs (B9999/A9999) for easy cleanup  
				- Validation queries to confirm trigger enforcement  

		• Error Message Clarity:  
			- Default SQL errors were too technical for end-users  
			- Enhanced with:  
				- Custom error messages via `SIGNAL SQLSTATE 45000`  
				- Context-specific messages (e.g., "Cannot schedule in past")  
