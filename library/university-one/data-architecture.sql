-- ============================================================================
-- University System - Data Architecture DDL
-- IBM AS/400 / DB2 for iSeries
-- Purpose: Core database schema for legacy modernization solution
-- Date: 1st Analysis
-- ============================================================================

-- ============================================================================
-- 1. DIMENSION TABLES (Reference Data)
-- ============================================================================

-- Department/Faculty Organization
CREATE TABLE departments (
    department_id   DECIMAL(4,0) NOT NULL PRIMARY KEY,
    department_name VARCHAR(100) NOT NULL,
    description     VARCHAR(500),
    campus_code     CHAR(3),
    created_date    DATE DEFAULT CURRENT_DATE,
    modified_date   TIMESTAMP
);

-- Academic Levels (Undergraduate, Graduate, etc.)
CREATE TABLE academic_levels (
    level_id        DECIMAL(2,0) NOT NULL PRIMARY KEY,
    level_name      VARCHAR(50) NOT NULL,
    level_code      CHAR(5) NOT NULL UNIQUE,
    description     VARCHAR(500)
);

-- Enrollment Status
CREATE TABLE enrollment_status (
    status_id       DECIMAL(2,0) NOT NULL PRIMARY KEY,
    status_name     VARCHAR(50) NOT NULL,
    status_code     CHAR(10) NOT NULL UNIQUE,
    description     VARCHAR(500)
);

-- Payment Status
CREATE TABLE payment_status (
    status_id       DECIMAL(2,0) NOT NULL PRIMARY KEY,
    status_name     VARCHAR(50) NOT NULL,
    status_code     CHAR(10) NOT NULL UNIQUE
);

-- Invoice Status
CREATE TABLE invoice_status (
    status_id       DECIMAL(2,0) NOT NULL PRIMARY KEY,
    status_name     VARCHAR(50) NOT NULL,
    status_code     CHAR(10) NOT NULL UNIQUE
);

-- Grade Codes
CREATE TABLE grade_codes (
    grade_id        DECIMAL(2,0) NOT NULL PRIMARY KEY,
    grade_letter    CHAR(2) NOT NULL UNIQUE,
    grade_point     DECIMAL(3,2),
    description     VARCHAR(100)
);

-- User Roles (for access control)
CREATE TABLE user_roles (
    role_id         DECIMAL(3,0) NOT NULL PRIMARY KEY,
    role_name       VARCHAR(50) NOT NULL UNIQUE,
    description     VARCHAR(500),
    created_date    DATE DEFAULT CURRENT_DATE
);

-- ============================================================================
-- 2. CORE ORGANIZATIONAL ENTITIES
-- ============================================================================

-- Persons (Base entity for students, faculty, staff)
CREATE TABLE persons (
    person_id           DECIMAL(10,0) NOT NULL PRIMARY KEY,
    first_name          VARCHAR(50) NOT NULL,
    middle_name         VARCHAR(50),
    last_name           VARCHAR(50) NOT NULL,
    date_of_birth       DATE,
    gender              CHAR(1),
    email               VARCHAR(100),
    phone_number        VARCHAR(20),
    address_street      VARCHAR(200),
    address_city        VARCHAR(50),
    address_state       CHAR(2),
    address_zip         VARCHAR(10),
    address_country     VARCHAR(50),
    ssn_or_id           VARCHAR(20) UNIQUE,
    creation_date       DATE DEFAULT CURRENT_DATE,
    modified_date       TIMESTAMP,
    last_login_date     DATE
);

-- Students
CREATE TABLE students (
    student_id          DECIMAL(10,0) NOT NULL PRIMARY KEY,
    person_id           DECIMAL(10,0) NOT NULL UNIQUE,
    student_number      VARCHAR(20) NOT NULL UNIQUE,
    admission_date      DATE NOT NULL,
    expected_graduation DATE,
    academic_level_id   DECIMAL(2,0),
    department_id       DECIMAL(4,0),
    status              CHAR(1) DEFAULT 'A',
    created_date        DATE DEFAULT CURRENT_DATE,
    modified_date       TIMESTAMP,
    FOREIGN KEY (person_id) REFERENCES persons(person_id),
    FOREIGN KEY (academic_level_id) REFERENCES academic_levels(level_id),
    FOREIGN KEY (department_id) REFERENCES departments(department_id)
);

-- Faculty/Instructors
CREATE TABLE faculty (
    faculty_id          DECIMAL(10,0) NOT NULL PRIMARY KEY,
    person_id           DECIMAL(10,0) NOT NULL UNIQUE,
    faculty_number      VARCHAR(20) NOT NULL UNIQUE,
    department_id       DECIMAL(4,0) NOT NULL,
    title               VARCHAR(50),
    hire_date           DATE,
    employment_status   CHAR(1) DEFAULT 'A',
    office_location     VARCHAR(100),
    office_phone        VARCHAR(20),
    created_date        DATE DEFAULT CURRENT_DATE,
    modified_date       TIMESTAMP,
    FOREIGN KEY (person_id) REFERENCES persons(person_id),
    FOREIGN KEY (department_id) REFERENCES departments(department_id)
);

-- Staff Members
CREATE TABLE staff (
    staff_id            DECIMAL(10,0) NOT NULL PRIMARY KEY,
    person_id           DECIMAL(10,0) NOT NULL UNIQUE,
    staff_number        VARCHAR(20) NOT NULL UNIQUE,
    department_id       DECIMAL(4,0),
    position_title      VARCHAR(100),
    hire_date           DATE,
    employment_status   CHAR(1) DEFAULT 'A',
    office_location     VARCHAR(100),
    created_date        DATE DEFAULT CURRENT_DATE,
    modified_date       TIMESTAMP,
    FOREIGN KEY (person_id) REFERENCES persons(person_id),
    FOREIGN KEY (department_id) REFERENCES departments(department_id)
);

-- ============================================================================
-- 3. ACADEMIC ENTITIES
-- ============================================================================

-- Academic Programs (Degree Programs)
CREATE TABLE academic_programs (
    program_id          DECIMAL(5,0) NOT NULL PRIMARY KEY,
    program_name        VARCHAR(150) NOT NULL,
    program_code        VARCHAR(20) NOT NULL UNIQUE,
    department_id       DECIMAL(4,0) NOT NULL,
    academic_level_id   DECIMAL(2,0) NOT NULL,
    degree_type         VARCHAR(50),
    total_credits       DECIMAL(3,0),
    description         VARCHAR(500),
    created_date        DATE DEFAULT CURRENT_DATE,
    modified_date       TIMESTAMP,
    FOREIGN KEY (department_id) REFERENCES departments(department_id),
    FOREIGN KEY (academic_level_id) REFERENCES academic_levels(level_id)
);

-- Student to Program Enrollment (Degree Track)
CREATE TABLE student_programs (
    student_program_id  DECIMAL(10,0) NOT NULL PRIMARY KEY,
    student_id          DECIMAL(10,0) NOT NULL,
    program_id          DECIMAL(5,0) NOT NULL,
    enrollment_date     DATE NOT NULL,
    expected_completion DATE,
    status              CHAR(1) DEFAULT 'A',
    gpa                 DECIMAL(3,2),
    created_date        DATE DEFAULT CURRENT_DATE,
    modified_date       TIMESTAMP,
    FOREIGN KEY (student_id) REFERENCES students(student_id),
    FOREIGN KEY (program_id) REFERENCES academic_programs(program_id),
    UNIQUE (student_id, program_id)
);

-- Courses
CREATE TABLE courses (
    course_id           DECIMAL(5,0) NOT NULL PRIMARY KEY,
    course_number       VARCHAR(20) NOT NULL,
    course_name         VARCHAR(150) NOT NULL,
    department_id       DECIMAL(4,0) NOT NULL,
    description         VARCHAR(500),
    credit_hours        DECIMAL(3,1) NOT NULL,
    prerequisites       VARCHAR(500),
    created_date        DATE DEFAULT CURRENT_DATE,
    modified_date       TIMESTAMP,
    FOREIGN KEY (department_id) REFERENCES departments(department_id),
    UNIQUE (course_number, department_id)
);

-- Course Sections/Classes (Actual offerings)
CREATE TABLE course_sections (
    section_id          DECIMAL(8,0) NOT NULL PRIMARY KEY,
    course_id           DECIMAL(5,0) NOT NULL,
    section_number      VARCHAR(10) NOT NULL,
    semester_code       VARCHAR(10) NOT NULL,
    year                DECIMAL(4,0) NOT NULL,
    instructor_id       DECIMAL(10,0),
    room_location       VARCHAR(100),
    meeting_days        VARCHAR(20),
    meeting_start_time  TIME,
    meeting_end_time    TIME,
    max_enrollment      DECIMAL(3,0),
    current_enrollment  DECIMAL(3,0) DEFAULT 0,
    status              CHAR(1) DEFAULT 'A',
    created_date        DATE DEFAULT CURRENT_DATE,
    modified_date       TIMESTAMP,
    FOREIGN KEY (course_id) REFERENCES courses(course_id),
    FOREIGN KEY (instructor_id) REFERENCES faculty(faculty_id),
    UNIQUE (course_id, section_number, semester_code, year)
);

-- Student Enrollment in Course Sections
CREATE TABLE enrollments (
    enrollment_id       DECIMAL(10,0) NOT NULL PRIMARY KEY,
    student_id          DECIMAL(10,0) NOT NULL,
    section_id          DECIMAL(8,0) NOT NULL,
    enrollment_date     DATE NOT NULL,
    status_id           DECIMAL(2,0),
    grade_id            DECIMAL(2,0),
    final_score         DECIMAL(5,2),
    created_date        DATE DEFAULT CURRENT_DATE,
    modified_date       TIMESTAMP,
    FOREIGN KEY (student_id) REFERENCES students(student_id),
    FOREIGN KEY (section_id) REFERENCES course_sections(section_id),
    FOREIGN KEY (status_id) REFERENCES enrollment_status(status_id),
    FOREIGN KEY (grade_id) REFERENCES grade_codes(grade_id),
    UNIQUE (student_id, section_id)
);

-- ============================================================================
-- 4. BILLING & FINANCIAL ENTITIES
-- ============================================================================

-- Billing Account
CREATE TABLE billing_accounts (
    billing_account_id  DECIMAL(10,0) NOT NULL PRIMARY KEY,
    student_id          DECIMAL(10,0) NOT NULL,
    account_number      VARCHAR(20) NOT NULL UNIQUE,
    account_holder_name VARCHAR(150),
    account_holder_id   DECIMAL(10,0),
    created_date        DATE DEFAULT CURRENT_DATE,
    modified_date       TIMESTAMP,
    FOREIGN KEY (student_id) REFERENCES students(student_id),
    FOREIGN KEY (account_holder_id) REFERENCES persons(person_id)
);

-- Invoices
CREATE TABLE invoices (
    invoice_id          DECIMAL(12,0) NOT NULL PRIMARY KEY,
    billing_account_id  DECIMAL(10,0) NOT NULL,
    invoice_number      VARCHAR(30) NOT NULL UNIQUE,
    invoice_date        DATE NOT NULL,
    due_date            DATE NOT NULL,
    status_id           DECIMAL(2,0),
    total_amount        DECIMAL(12,2) NOT NULL,
    amount_paid         DECIMAL(12,2) DEFAULT 0,
    amount_due          DECIMAL(12,2),
    semester_code       VARCHAR(10),
    notes               VARCHAR(500),
    created_date        DATE DEFAULT CURRENT_DATE,
    modified_date       TIMESTAMP,
    FOREIGN KEY (billing_account_id) REFERENCES billing_accounts(billing_account_id),
    FOREIGN KEY (status_id) REFERENCES invoice_status(status_id)
);

-- Invoice Line Items
CREATE TABLE invoice_line_items (
    line_item_id        DECIMAL(12,0) NOT NULL PRIMARY KEY,
    invoice_id          DECIMAL(12,0) NOT NULL,
    line_item_type      VARCHAR(50),
    description         VARCHAR(200) NOT NULL,
    quantity            DECIMAL(5,0),
    unit_amount         DECIMAL(12,2) NOT NULL,
    line_amount         DECIMAL(12,2) NOT NULL,
    created_date        DATE DEFAULT CURRENT_DATE,
    FOREIGN KEY (invoice_id) REFERENCES invoices(invoice_id)
);

-- Payments
CREATE TABLE payments (
    payment_id          DECIMAL(12,0) NOT NULL PRIMARY KEY,
    billing_account_id  DECIMAL(10,0) NOT NULL,
    invoice_id          DECIMAL(12,0),
    payment_date        DATE NOT NULL,
    payment_amount      DECIMAL(12,2) NOT NULL,
    payment_method      VARCHAR(30),
    status_id           DECIMAL(2,0),
    reference_number    VARCHAR(50),
    notes               VARCHAR(500),
    created_date        DATE DEFAULT CURRENT_DATE,
    modified_date       TIMESTAMP,
    FOREIGN KEY (billing_account_id) REFERENCES billing_accounts(billing_account_id),
    FOREIGN KEY (invoice_id) REFERENCES invoices(invoice_id),
    FOREIGN KEY (status_id) REFERENCES payment_status(status_id)
);

-- ============================================================================
-- 5. SECURITY & ACCESS CONTROL
-- ============================================================================

-- User Accounts (for system access)
CREATE TABLE user_accounts (
    user_account_id     DECIMAL(10,0) NOT NULL PRIMARY KEY,
    person_id           DECIMAL(10,0) NOT NULL UNIQUE,
    username            VARCHAR(50) NOT NULL UNIQUE,
    password_hash       VARCHAR(500),
    is_active           CHAR(1) DEFAULT 'Y',
    account_locked      CHAR(1) DEFAULT 'N',
    last_password_change DATE,
    created_date        DATE DEFAULT CURRENT_DATE,
    modified_date       TIMESTAMP,
    FOREIGN KEY (person_id) REFERENCES persons(person_id)
);

-- User Role Assignments
CREATE TABLE user_role_assignments (
    assignment_id       DECIMAL(10,0) NOT NULL PRIMARY KEY,
    user_account_id     DECIMAL(10,0) NOT NULL,
    role_id             DECIMAL(3,0) NOT NULL,
    assigned_date       DATE NOT NULL DEFAULT CURRENT_DATE,
    expiration_date     DATE,
    is_active           CHAR(1) DEFAULT 'Y',
    created_date        DATE DEFAULT CURRENT_DATE,
    modified_date       TIMESTAMP,
    FOREIGN KEY (user_account_id) REFERENCES user_accounts(user_account_id),
    FOREIGN KEY (role_id) REFERENCES user_roles(role_id),
    UNIQUE (user_account_id, role_id, assigned_date)
);

-- ============================================================================
-- 6. AUDIT & LOGGING
-- ============================================================================

-- System Audit Log
CREATE TABLE system_audit_log (
    audit_id            DECIMAL(15,0) NOT NULL PRIMARY KEY,
    user_account_id     DECIMAL(10,0),
    action_type         VARCHAR(50) NOT NULL,
    table_name          VARCHAR(50),
    record_id           VARCHAR(50),
    old_values          VARCHAR(2000),
    new_values          VARCHAR(2000),
    ip_address          VARCHAR(50),
    action_timestamp    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_account_id) REFERENCES user_accounts(user_account_id)
);

-- API Request Log
CREATE TABLE api_request_log (
    request_id          DECIMAL(15,0) NOT NULL PRIMARY KEY,
    user_account_id     DECIMAL(10,0),
    endpoint            VARCHAR(500) NOT NULL,
    http_method         VARCHAR(10),
    request_data        VARCHAR(2000),
    response_code       DECIMAL(3,0),
    response_time_ms    DECIMAL(10,0),
    ip_address          VARCHAR(50),
    request_timestamp   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_account_id) REFERENCES user_accounts(user_account_id)
);

-- ============================================================================
-- 7. INDEXES FOR PERFORMANCE
-- ============================================================================

-- Student lookup indexes
CREATE INDEX idx_student_number ON students(student_number);
CREATE INDEX idx_student_person_id ON students(person_id);
CREATE INDEX idx_student_department ON students(department_id);

-- Faculty lookup indexes
CREATE INDEX idx_faculty_number ON faculty(faculty_number);
CREATE INDEX idx_faculty_department ON faculty(department_id);

-- Course lookup indexes
CREATE INDEX idx_course_number ON courses(course_number);
CREATE INDEX idx_course_department ON courses(department_id);
CREATE INDEX idx_section_course ON course_sections(course_id);
CREATE INDEX idx_section_instructor ON course_sections(instructor_id);
CREATE INDEX idx_section_semester ON course_sections(semester_code, year);

-- Enrollment lookup indexes
CREATE INDEX idx_enrollment_student ON enrollments(student_id);
CREATE INDEX idx_enrollment_section ON enrollments(section_id);
CREATE INDEX idx_enrollment_status ON enrollments(status_id);

-- Billing lookup indexes
CREATE INDEX idx_billing_student ON billing_accounts(student_id);
CREATE INDEX idx_invoice_account ON invoices(billing_account_id);
CREATE INDEX idx_invoice_date ON invoices(invoice_date);
CREATE INDEX idx_invoice_status ON invoices(status_id);
CREATE INDEX idx_payment_account ON payments(billing_account_id);
CREATE INDEX idx_payment_invoice ON payments(invoice_id);
CREATE INDEX idx_payment_date ON payments(payment_date);

-- User lookup indexes
CREATE INDEX idx_user_username ON user_accounts(username);
CREATE INDEX idx_user_person ON user_accounts(person_id);
CREATE INDEX idx_user_role_user ON user_role_assignments(user_account_id);
CREATE INDEX idx_user_role_role ON user_role_assignments(role_id);

-- Audit indexes
CREATE INDEX idx_audit_user ON system_audit_log(user_account_id);
CREATE INDEX idx_audit_timestamp ON system_audit_log(action_timestamp);
CREATE INDEX idx_api_user ON api_request_log(user_account_id);
CREATE INDEX idx_api_timestamp ON api_request_log(request_timestamp);

-- ============================================================================
-- 8. INITIAL DATA LOADING (Reference Data)
-- ============================================================================

-- Insert Academic Levels
INSERT INTO academic_levels VALUES (1, 'Undergraduate', 'UG', 'Undergraduate degree program');
INSERT INTO academic_levels VALUES (2, 'Graduate', 'GR', 'Graduate degree program');
INSERT INTO academic_levels VALUES (3, 'Doctoral', 'DR', 'Doctoral degree program');

-- Insert Enrollment Status
INSERT INTO enrollment_status VALUES (1, 'Active', 'ACTIVE', 'Student actively enrolled');
INSERT INTO enrollment_status VALUES (2, 'Withdrawn', 'WITHDRAWN', 'Student has withdrawn');
INSERT INTO enrollment_status VALUES (3, 'Completed', 'COMPLETED', 'Course completed');
INSERT INTO enrollment_status VALUES (4, 'Dropped', 'DROPPED', 'Course dropped by student');

-- Insert Payment Status
INSERT INTO payment_status VALUES (1, 'Pending', 'PENDING', 'Payment pending');
INSERT INTO payment_status VALUES (2, 'Processed', 'PROCESSED', 'Payment processed');
INSERT INTO payment_status VALUES (3, 'Failed', 'FAILED', 'Payment failed');
INSERT INTO payment_status VALUES (4, 'Refunded', 'REFUNDED', 'Payment refunded');

-- Insert Invoice Status
INSERT INTO invoice_status VALUES (1, 'Draft', 'DRAFT', 'Invoice draft');
INSERT INTO invoice_status VALUES (2, 'Issued', 'ISSUED', 'Invoice issued to student');
INSERT INTO invoice_status VALUES (3, 'Paid', 'PAID', 'Invoice fully paid');
INSERT INTO invoice_status VALUES (4, 'Overdue', 'OVERDUE', 'Invoice overdue');
INSERT INTO invoice_status VALUES (5, 'Cancelled', 'CANCELLED', 'Invoice cancelled');

-- Insert Grade Codes
INSERT INTO grade_codes VALUES (1, 'A', 4.00, 'Excellent');
INSERT INTO grade_codes VALUES (2, 'A-', 3.70, 'Very Good');
INSERT INTO grade_codes VALUES (3, 'B+', 3.30, 'Good Plus');
INSERT INTO grade_codes VALUES (4, 'B', 3.00, 'Good');
INSERT INTO grade_codes VALUES (5, 'B-', 2.70, 'Good Minus');
INSERT INTO grade_codes VALUES (6, 'C+', 2.30, 'Satisfactory Plus');
INSERT INTO grade_codes VALUES (7, 'C', 2.00, 'Satisfactory');
INSERT INTO grade_codes VALUES (8, 'C-', 1.70, 'Satisfactory Minus');
INSERT INTO grade_codes VALUES (9, 'D', 1.00, 'Poor');
INSERT INTO grade_codes VALUES (10, 'F', 0.00, 'Fail');

-- Insert User Roles
INSERT INTO user_roles VALUES (1, 'Administrator', 'System administrator with full access');
INSERT INTO user_roles VALUES (2, 'Student', 'Student access to own data');
INSERT INTO user_roles VALUES (3, 'Faculty', 'Faculty access to course and grade data');
INSERT INTO user_roles VALUES (4, 'Financial', 'Financial/Billing staff access');
INSERT INTO user_roles VALUES (5, 'Registrar', 'Registrar access to academic records');
INSERT INTO user_roles VALUES (6, 'Manager', 'Department manager access');

-- ============================================================================
-- 9. VIEWS FOR API DATA CONTRACTS
-- ============================================================================

-- Student Portal View
CREATE VIEW student_portal_view AS
SELECT 
    s.student_id,
    s.student_number,
    p.first_name,
    p.last_name,
    p.email,
    p.phone_number,
    s.admission_date,
    s.expected_graduation,
    al.level_name,
    d.department_name,
    s.status
FROM 
    students s
    JOIN persons p ON s.person_id = p.person_id
    JOIN academic_levels al ON s.academic_level_id = al.level_id
    JOIN departments d ON s.department_id = d.department_id;

-- Billing Summary View
CREATE VIEW student_billing_summary AS
SELECT 
    ba.billing_account_id,
    s.student_number,
    p.first_name,
    p.last_name,
    SUM(CASE WHEN i.status_id IN (2,4) THEN i.amount_due ELSE 0 END) as total_due,
    SUM(CASE WHEN i.status_id = 3 THEN i.total_amount ELSE 0 END) as total_paid,
    COUNT(DISTINCT CASE WHEN i.status_id = 4 THEN i.invoice_id END) as overdue_invoices
FROM 
    billing_accounts ba
    JOIN students s ON ba.student_id = s.student_id
    JOIN persons p ON s.person_id = p.person_id
    LEFT JOIN invoices i ON ba.billing_account_id = i.billing_account_id
GROUP BY 
    ba.billing_account_id, s.student_number, p.first_name, p.last_name;

-- Student Enrollment Summary View
CREATE VIEW student_enrollment_summary AS
SELECT 
    s.student_id,
    s.student_number,
    p.first_name,
    p.last_name,
    cs.semester_code,
    cs.year,
    COUNT(*) as courses_enrolled,
    SUM(c.credit_hours) as total_credits
FROM 
    students s
    JOIN persons p ON s.person_id = p.person_id
    JOIN enrollments e ON s.student_id = e.student_id
    JOIN course_sections cs ON e.section_id = cs.section_id
    JOIN courses c ON cs.course_id = c.course_id
WHERE 
    e.status_id IN (1, 3)
GROUP BY 
    s.student_id, s.student_number, p.first_name, p.last_name, 
    cs.semester_code, cs.year;

-- ============================================================================
-- 10. STORED PROCEDURES FOR COMMON OPERATIONS
-- ============================================================================

-- Procedure to record a payment
CREATE PROCEDURE record_payment (
    IN p_billing_account_id DECIMAL(10,0),
    IN p_invoice_id DECIMAL(12,0),
    IN p_payment_amount DECIMAL(12,2),
    IN p_payment_method VARCHAR(30),
    IN p_reference_number VARCHAR(50),
    OUT p_payment_id DECIMAL(12,0)
)
LANGUAGE SQL
BEGIN
    -- Insert payment record
    INSERT INTO payments (
        payment_id, billing_account_id, invoice_id, payment_date,
        payment_amount, payment_method, status_id, reference_number,
        created_date
    ) VALUES (
        (SELECT MAX(payment_id) + 1 FROM payments),
        p_billing_account_id,
        p_invoice_id,
        CURRENT_DATE,
        p_payment_amount,
        p_payment_method,
        2, -- Processed status
        p_reference_number,
        CURRENT_DATE
    );
    
    -- Get the new payment ID
    SET p_payment_id = (SELECT MAX(payment_id) FROM payments);
    
    -- Update invoice status if fully paid
    UPDATE invoices
    SET amount_paid = amount_paid + p_payment_amount,
        amount_due = total_amount - (amount_paid + p_payment_amount),
        status_id = CASE WHEN (total_amount - (amount_paid + p_payment_amount)) <= 0 THEN 3 ELSE 2 END,
        modified_date = CURRENT_TIMESTAMP
    WHERE invoice_id = p_invoice_id;
END;

-- Procedure to enroll student in course
CREATE PROCEDURE enroll_student (
    IN p_student_id DECIMAL(10,0),
    IN p_section_id DECIMAL(8,0),
    OUT p_enrollment_id DECIMAL(10,0)
)
LANGUAGE SQL
BEGIN
    -- Check if section has available seats
    IF (SELECT (max_enrollment - current_enrollment) FROM course_sections 
        WHERE section_id = p_section_id) <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No seats available in section';
    END IF;
    
    -- Insert enrollment
    INSERT INTO enrollments (
        enrollment_id, student_id, section_id, enrollment_date,
        status_id, created_date
    ) VALUES (
        (SELECT MAX(enrollment_id) + 1 FROM enrollments),
        p_student_id,
        p_section_id,
        CURRENT_DATE,
        1, -- Active status
        CURRENT_DATE
    );
    
    SET p_enrollment_id = (SELECT MAX(enrollment_id) FROM enrollments);
    
    -- Update current enrollment count
    UPDATE course_sections
    SET current_enrollment = current_enrollment + 1
    WHERE section_id = p_section_id;
END;

-- ============================================================================
-- NOTES
-- ============================================================================
-- 1. This schema supports the API-First modernization approach
-- 2. All tables include audit fields (created_date, modified_date)
-- 3. Foreign key constraints ensure referential integrity
-- 4. Indexes optimize common query patterns
-- 5. Views provide API data contracts
-- 6. Stored procedures encapsulate business logic
-- 7. Reference data is preloaded for immediate use
-- 8. The schema can be extended incrementally without breaking existing APIs
-- ============================================================================
