USE Zillow_data;
-- Tạo các vai trò
CREATE ROLE AdminRole;
CREATE ROLE EngineerRole;
CREATE ROLE AnalystRole;
CREATE ROLE OperatorRole;
CREATE ROLE GuestRole;
USE master;
--Tạo login trên server
CREATE LOGIN admin_user WITH PASSWORD = 'Admin_07';
CREATE LOGIN engineer_user WITH PASSWORD = 'Engineer_07';
CREATE LOGIN analyst_user WITH PASSWORD = 'Analyst_07';
CREATE LOGIN operator_user WITH PASSWORD = 'Operator_07';
CREATE LOGIN guest_user WITH PASSWORD = 'Guest_07';

-- Tạo user trong cơ sở dữ liệu (Zillow_data)
USE Zillow_data;
CREATE USER admin_user FOR LOGIN admin_user;
CREATE USER engineer_user FOR LOGIN engineer_user;
CREATE USER analyst_user FOR LOGIN analyst_user;
CREATE USER operator_user FOR LOGIN operator_user;
CREATE USER guest_user FOR LOGIN guest_user;


--Gán vai trò cho người dùng
-- Gán vai trò Admin cho người dùng 'admin_user'
ALTER ROLE AdminRole ADD MEMBER admin_user;

-- Gán vai trò Engineer cho người dùng 'engineer_user'
ALTER ROLE EngineerRole ADD MEMBER engineer_user;

-- Gán vai trò Analyst cho người dùng 'analyst_user'
ALTER ROLE AnalystRole ADD MEMBER analyst_user;

-- Gán vai trò Operator cho người dùng 'operator_user'
ALTER ROLE OperatorRole ADD MEMBER operator_user;

-- Gán vai trò Guest cho người dùng 'guest_user'
ALTER ROLE GuestRole ADD MEMBER guest_user;

-- Admin
-- Toàn quyền trên cơ sở dữ liệu
GRANT CONTROL ON DATABASE::Zillow_data TO [admin_user];
GRANT ALTER ON DATABASE::Zillow_data TO [admin_user];

-- Toàn quyền chỉnh sửa schema dbo
GRANT ALTER ON SCHEMA::dbo TO [admin_user];
GRANT CONTROL ON SCHEMA::dbo TO [admin_user];

-- Cấp quyền trên toàn bộ schema dbo
GRANT ALTER ON SCHEMA::dbo TO [admin_user];
GRANT DELETE, INSERT, UPDATE, SELECT ON SCHEMA::dbo TO [admin_user];

-- Cấp quyền backup trực tiếp cho admin_user (vẫn hợp lệ)
GRANT BACKUP DATABASE TO [admin_user];
-- Gán quyền dbcreator cho admin_user
ALTER SERVER ROLE dbcreator ADD MEMBER [admin_user];

--Engineer
-- Quyền chỉ đọc trên bảng thô 
GRANT SELECT ON OBJECT::[dbo].[Zillow_Raw]TO [engineer_user];

-- Quyền chỉ đọc và xóa trên bảng đã xử lý (Zillow_table)
GRANT SELECT, DELETE ON OBJECT::[dbo].[Zillow_table] TO [engineer_user];

-- Quyền thực thi thủ tục xử lý dữ liệu
GRANT EXECUTE ON OBJECT::dbo.Delete_Duplicates TO [engineer_user];
GRANT EXECUTE ON OBJECT::dbo.Update_adr TO [engineer_user];
GRANT EXECUTE ON OBJECT::dbo.Update_Details TO [engineer_user];
GRANT EXECUTE ON OBJECT::dbo.Update_Price TO [engineer_user];
GRANT EXECUTE ON OBJECT::dbo.Delete_Null TO [engineer_user];
--Analyst
-- Quyền xem dữ liệu đã xử lý
GRANT SELECT ON OBJECT::[dbo].[Zillow_table] TO [analyst_user];
GRANT SELECT ON OBJECT::[dbo].[Properties_table] TO [analyst_user];
GRANT SELECT ON OBJECT::[dbo].[City_table] TO [analyst_user];
GRANT SELECT ON OBJECT::[dbo].[State_table] TO [analyst_user];
GRANT SELECT ON OBJECT::[dbo].[Properties_Details_table] TO [analyst_user];
GRANT SELECT ON OBJECT::[dbo].[House_Type_table] TO [analyst_user];

-- Quyền tạo và xem view
GRANT CREATE VIEW TO [analyst_user];

--Operator
-- Quyền thực thi các thủ tục nhập liệu
GRANT EXECUTE ON OBJECT::dbo.InsertData TO [operator_user];

-- Quyền xem dữ liệu liên quan
GRANT SELECT ON OBJECT::[dbo].[Properties_table] TO [operator_user];
GRANT SELECT ON OBJECT::[dbo].[City_table] TO [operator_user];
GRANT SELECT ON OBJECT::[dbo].[State_table] TO[operator_user];
GRANT SELECT ON OBJECT::[dbo].[Properties_Details_table] TO [operator_user];
GRANT SELECT ON OBJECT::[dbo].[House_Type_table] TO [operator_user];

--Guest
-- Quyền chỉ xem dữ liệu đã xử lý
GRANT SELECT ON OBJECT::[dbo].[Properties_table] TO [guest_user];
GRANT SELECT ON OBJECT::[dbo].[City_table] TO [guest_user];
GRANT SELECT ON OBJECT::[dbo].[State_table] TO [guest_user];
GRANT SELECT ON OBJECT::[dbo].[Properties_Details_table] TO [guest_user];
GRANT SELECT ON OBJECT::[dbo].[House_Type_table] TO [guest_user];

--------------------------------------
use master
-- Tạo audit để ghi lại các hoạt động
CREATE SERVER AUDIT Zillow_Audit_G7
TO FILE (FILEPATH = 'D:\PhanQuyen' -- Đường dẫn file audit
         , MAXSIZE = 10 MB, MAX_ROLLOVER_FILES = 5);

-- Bật audit
ALTER SERVER AUDIT Zillow_Audit_G7 WITH (STATE = ON);

USE Zillow_data;

-- Ghi nhận mọi hành động trên cơ sở dữ liệu
CREATE DATABASE AUDIT SPECIFICATION Zillow_AuditSpec_G7
FOR SERVER AUDIT Zillow_Audit_G7
ADD (SELECT ON DATABASE::Zillow_data BY PUBLIC),
ADD (INSERT ON DATABASE::Zillow_data BY PUBLIC),
ADD (UPDATE ON DATABASE::Zillow_data BY PUBLIC),
ADD (DELETE ON DATABASE::Zillow_data BY PUBLIC),
ADD (EXECUTE ON DATABASE::Zillow_data BY PUBLIC);
-- Bật audit specification
ALTER DATABASE AUDIT SPECIFICATION Zillow_AuditSpec_G7 WITH (STATE = ON);
---
SELECT * 
FROM sys.fn_get_audit_file ('D:\PhanQuyen', DEFAULT, DEFAULT);
-----Kiểm tra phân quyen
SELECT dp.name AS UserName, 
       dp.type_desc AS UserType, 
       p.permission_name, 
       p.state_desc
FROM sys.database_permissions p
JOIN sys.database_principals dp ON p.grantee_principal_id = dp.principal_id
WHERE dp.name = 'admin_user';
-----
-- Thu hồi quyền từ người dùng 'admin_user'
REVOKE CONTROL ON DATABASE::Zillow_data FROM [admin_user];
REVOKE ALTER ON DATABASE::Zillow_data FROM [admin_user];
REVOKE ALTER ON SCHEMA::dbo FROM [admin_user];
REVOKE DELETE, INSERT, UPDATE, SELECT ON SCHEMA::dbo FROM [admin_user];
REVOKE BACKUP DATABASE FROM [admin_user];

-- Thu hồi quyền từ người dùng 'engineer_user'
REVOKE SELECT ON OBJECT::[dbo].[Zillow_Raw] FROM [engineer_user];
REVOKE SELECT, DELETE ON OBJECT::[dbo].[Zillow_table] FROM [engineer_user];
REVOKE EXECUTE ON OBJECT::dbo.UpdateHouseID FROM [engineer_user];
REVOKE EXECUTE ON OBJECT::dbo.Delete_Duplicates FROM [engineer_user];
REVOKE EXECUTE ON OBJECT::dbo.Update_adr FROM [engineer_user];
REVOKE EXECUTE ON OBJECT::dbo.Update_Details FROM [engineer_user];
REVOKE EXECUTE ON OBJECT::dbo.Update_Price FROM [engineer_user];
REVOKE EXECUTE ON OBJECT::dbo.Delete_Null FROM [engineer_user];

-- Thu hồi quyền từ người dùng 'analyst_user'
REVOKE SELECT ON OBJECT::[dbo].[Zillow_table] FROM [analyst_user];
REVOKE CREATE VIEW FROM [analyst_user];

-- Thu hồi quyền từ người dùng 'operator_user'
REVOKE EXECUTE ON OBJECT::dbo.InsertData FROM [operator_user];
REVOKE SELECT ON OBJECT::[dbo].[Properties_table] FROM [operator_user];

-- Thu hồi quyền từ người dùng 'guest_user'
REVOKE SELECT ON OBJECT::[dbo].[Properties_table] FROM [guest_user];
-- Thu hồi vai trò từ người dùng
ALTER ROLE AdminRole DROP MEMBER admin_user;
ALTER ROLE EngineerRole DROP MEMBER engineer_user;
ALTER ROLE AnalystRole DROP MEMBER analyst_user;
ALTER ROLE OperatorRole DROP MEMBER operator_user;
ALTER ROLE GuestRole DROP MEMBER guest_user;
-- Xoá quyền nếu không cần 
DROP ROLE AdminRole;
DROP ROLE EngineerRole;
DROP ROLE AnalystRole;
DROP ROLE OperatorRole;
DROP ROLE GuestRole;
