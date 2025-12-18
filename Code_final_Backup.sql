--1 Khai báo database
use Zillow_data
------------------------------------------------------------------------------------------------------------------
--2.Tạo full backup 
BACKUP DATABASE Zillow_data
TO DISK = 'D:\Backups\Zillow_data_full.bak'
WITH INIT, NAME = 'Full Backup of Zillow_data';
GO
------------------------------------------------------------------------------------------------------------------
--3.Tạo differential backup
BACKUP DATABASE Zillow_data
TO DISK = 'D:\Backups\Zillow_data_diff.bak'
WITH DIFFERENTIAL, NAME = 'Differential Backup of Zillow_data';
GO
------------------------------------------------------------------------------------------------------------------
--4 .Tạo backup tự động
USE msdb;
GO

EXEC dbo.sp_add_job
    @job_name = 'Weekly Differential Backup';

EXEC sp_add_jobstep
    @job_name = 'Weekly Differential Backup',
    @step_name = 'Perform Differential_backup',
    @subsystem = 'TSQL',
    @command = 'BACKUP DATABASE Zillow_data TO DISK = ''D:\Backups\Zillow_data_diff.bak'' WITH DIFFERENTIAL,
	NAME = ''Differential Backup of Zillow_data'';',
    @on_success_action = 1,
    @on_fail_action = 2;

EXEC sp_add_schedule
    @schedule_name = 'Weekly_Backup_Schedule',
    @freq_type = 8, -- Weekly
    @freq_interval = 2, -- Monday
    @freq_recurrence_factor = 1, -- Tần suất hàng tuần
    @active_start_time = 030000; -- 3:00 AM


EXEC sp_attach_schedule
    @job_name = 'Weekly Differential Backup',
    @schedule_name = 'Weekly_Backup_Schedule';

EXEC sp_add_jobserver
    @job_name = 'Weekly Differential Backup';
GO
------------------------------------------------------------------------------------------------------------------
--5. Kiểm tra:
--a) Lịch sử backup
GO
CREATE PROCEDURE Get_Backup_History
    @DatabaseName NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        backup_start_date,
        backup_finish_date,
        CASE 
            WHEN type = 'D' THEN 'Full'
            WHEN type = 'I' THEN 'Differential'
            ELSE 'Other'
        END AS backup_type,
        database_name,
        physical_device_name,
        position,
        name AS backupset_name,
        description
    FROM msdb.dbo.backupset
    JOIN msdb.dbo.backupmediafamily
        ON backupset.media_set_id = backupmediafamily.media_set_id
    WHERE database_name = @DatabaseName
    ORDER BY backup_start_date DESC;
END;
GO

EXEC Get_Backup_History @DatabaseName = 'Zillow_data';
------------------------------------------------------------------------------------------------------------------
--b) Kiểm tra lịch sử job backup
GO
CREATE PROCEDURE Job_Backup_History
    @DatabaseName NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
    j.name AS job_name,
    h.run_date,
    h.run_time,
    CASE 
        WHEN h.run_status = 0 THEN 'Failed'
        WHEN h.run_status = 1 THEN 'Succeeded'
        WHEN h.run_status = 2 THEN 'Retry'
        WHEN h.run_status = 3 THEN 'Canceled'
        WHEN h.run_status = 4 THEN 'In Progress'
    END AS job_status,
    h.message
FROM msdb.dbo.sysjobs j
JOIN msdb.dbo.sysjobhistory h
    ON j.job_id = h.job_id
WHERE j.name = 'Weekly Differential Backup'
ORDER BY h.run_date DESC, h.run_time DESC;
END;
GO
EXEC Job_Backup_History @DatabaseName = 'Zillow_data';
------------------------------------------------------------------------------------------------------------------
--c.	Theo dõi tiến trình backup đang chạy
GO
CREATE PROCEDURE Run_Backup_History
    @DatabaseName NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;

	SELECT 
		r.session_id,
		r.command,
		r.start_time,
		r.percent_complete,
		r.estimated_completion_time,
		r.total_elapsed_time,
		r.database_id,
		d.name AS database_name
	FROM sys.dm_exec_requests r
	JOIN sys.databases d
		ON r.database_id = d.database_id
	WHERE r.command LIKE 'BACKUP%';
END;
GO
EXEC Run_Backup_History @DatabaseName = 'Zillow_data';
------------------------------------------------------------------------------------------------------------------
--6. Xoá lịch sử, dữ liệu sao lưu nếu được ghi lại quá 30 ngày:
USE msdb;
GO

-- a. Tạo công việc
EXEC dbo.sp_add_job
    @job_name = 'Weekly_Maintenance_Clean',
    @enabled = 1,  -- Công việc được kích hoạt
    @description = 'Job to delete old backup files older than 30 days',
    @start_step_id = 1,
    @category_name = 'Database Maintenance';
GO
--b. Thêm lệnh xoá
EXEC dbo.sp_add_jobstep
    @job_name = 'Weekly_Maintenance_Clean', -- Tên công việc đã tạo
    @step_name = 'Delete Old Backup Files',
    @subsystem = 'TSQL',
    @command = 'EXECUTE master.dbo.xp_delete_file 0, ''D:\Backups\Zillow_data_diff.bak'', ''BAK'', 30;',
    @on_success_action = 1, -- Chuyển sang bước tiếp theo
    @on_fail_action = 2; -- Ngừng công việc nếu thất bại
GO
--c. Thiết lập tự động
EXEC sp_add_schedule
    @schedule_name = 'Weekly_Clean_Schedule',
    @freq_type = 8, -- Chạy hàng tuần
    @freq_interval = 2, -- Thứ Hai
    @freq_recurrence_factor = 1, -- Lặp lại hàng tuần
    @active_start_time = 030000; -- 3:00 AM
GO
-- Gắn lịch chạy vào công việc
EXEC sp_attach_schedule
    @job_name = 'Weekly_Maintenance_Clean',
    @schedule_name = 'Weekly_Clean_Schedule';
GO