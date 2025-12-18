--1 Xử lý dữ liệu
--Tạo cột House_ID
CREATE PROCEDURE Add_House_ID
AS
BEGIN
    -- Thêm cột House_ID vào bảng
    ALTER TABLE [dbo].[Zillow_table]
    ADD House_ID VARCHAR(50);
END

EXEC Add_House_ID

--Nhập cột House_ID
CREATE PROCEDURE Update_House_ID
AS
BEGIN
    UPDATE [dbo].[Zillow_table]
    SET House_ID =	RIGHT(
						LEFT(Links, CHARINDEX('_zpid', Links) - 1), 
						CHARINDEX('/', 
							REVERSE(
								LEFT(Links, CHARINDEX('_zpid', Links) - 1)
							)
						) - 1
					);
END

EXEC Update_House_ID

--Xoá dòng trùng
CREATE PROCEDURE Delete_Duplicates
AS
BEGIN
    WITH CTE_Duplicates AS (
        SELECT *, 
			   ROW_NUMBER() OVER (
					PARTITION BY House_ID
					ORDER BY (SELECT NULL)
				) AS rn
        FROM [dbo].[Zillow_table]
    )
    DELETE FROM CTE_Duplicates 
    WHERE rn > 1;
END

EXEC Delete_Duplicates


--Tách address
--Tạo các cột address
CREATE PROCEDURE Create_Adr
AS
BEGIN
	ALTER TABLE [dbo].[Zillow_table]
	ADD Street_adr	NVARCHAR(255),
		City_adr	NVARCHAR(255),
		State_adr	NVARCHAR(50),
		Zip_Code	NVARCHAR(10);
END

EXEC Create_Adr

--Thêm dữ liệu vào các cột address
CREATE PROCEDURE Update_adr
AS
BEGIN
    UPDATE [dbo].[Zillow_table]
    SET 
        -- Cập nhật giá trị cho Street
        Street_adr = CASE 
						WHEN CHARINDEX(',', Address) > 0 
						THEN LEFT(Address, CHARINDEX(',', Address) - 1) 
						ELSE Address 
					 END,

        -- Cập nhật giá trị cho City
        City_adr =	CASE 
						WHEN CHARINDEX(',', Address) > 0 
							 AND CHARINDEX(',', Address, CHARINDEX(',', Address) + 1) > 0 
						THEN LTRIM(
								SUBSTRING(
									Address, 
									CHARINDEX(',', Address) + 1, 
									CHARINDEX(',', Address, CHARINDEX(',', Address) + 1) - CHARINDEX(',', Address) - 1
								)
							 ) 
						ELSE NULL 
					END,

        -- Cập nhật giá trị cho State
        State_adr = CASE 
						WHEN CHARINDEX(',', Address, CHARINDEX(',', Address) + 1) > 0 
						THEN LTRIM(
								SUBSTRING(
									Address, 
									CHARINDEX(',', Address, CHARINDEX(',', Address) + 1) + 1,
									3
								)
							 ) 
						ELSE NULL 
					END,

        -- Cập nhật giá trị cho Zip Code
        Zip_Code = CASE 
                      WHEN LEN(Address) >= 5 
                      THEN RIGHT(Address, 5) 
                      ELSE NULL 
                   END;
END;

EXEC Update_adr

--Tách detail
--Tạo các cột thuộc details
CREATE PROCEDURE Create_details
AS
BEGIN
    ALTER TABLE [dbo].[Zillow_table]
    ADD Bedrooms		INT,
        Bathrooms		INT,
        Square_Footage	INT;
END

EXEC Create_details

--Thêm dữ liệu vào các cột details
CREATE PROCEDURE Update_Details
AS
BEGIN
    UPDATE [dbo].[Zillow_table]
    SET 
        -- Cập nhật số phòng ngủ (Bedrooms)
        Bedrooms =	CASE 
						WHEN (CHARINDEX(' bds', Details) > 0 OR CHARINDEX(' bd', Details) > 0) 
							 AND ISNUMERIC(LEFT(Details, CHARINDEX(' ', Details) - 1)) = 1
						THEN TRY_CAST(
								LTRIM(RTRIM(
										LEFT(Details, CHARINDEX(' ', Details) - 1)
									  )
								) AS INT
							 )
						ELSE 
							CASE 
								WHEN CHARINDEX(' ba', Details) > 0 
										AND LEFT(Details, CHARINDEX(' ba', Details) - 1) LIKE '%Studio%' 
								THEN 0
								ELSE NULL
							END
						END,

        -- Cập nhật số phòng tắm (Bathrooms)
        Bathrooms = CASE 
						WHEN CHARINDEX(' ba', Details) > 0 
						THEN TRY_CAST(
								SUBSTRING(
									Details, 
									CHARINDEX(' ba', Details) - 1, 
									1
								) AS INT
							 )
						ELSE NULL 
					END,

        -- Cập nhật diện tích (Square Footage)
        Square_Footage = CASE 
							WHEN CHARINDEX('sqft', Details) > 0 
								 AND CHARINDEX(' ba', Details) > 0 
							THEN 
								CASE 
									WHEN SUBSTRING(
											Details, 
											CHARINDEX(' ba', Details) + 3, 
											LEN(Details)
										 ) LIKE '%--%' 
									THEN NULL
									ELSE TRY_CAST(
											REPLACE(	
												LTRIM(RTRIM(
														SUBSTRING(
															Details, 
															CHARINDEX(' ba', Details) + 3, 
															CHARINDEX('sqft', Details) - CHARINDEX(' ba', Details) - 3
														)
												)),
												',', 
												''
											) AS INT
										 )
								END
							ELSE NULL 
						 END
    WHERE 
        Details IS NOT NULL;
END;

EXEC Update_Details


--Xử lý Price
CREATE PROCEDURE Update_Price
AS
BEGIN
    UPDATE [dbo].[Zillow_table]
    SET Price = CASE
					WHEN CHARINDEX('.', Price) > 0 
						 OR CHARINDEX('--', Price) > 0 
					THEN NULL                            -- dòng nào có dấu '.' hoặc '--' thì trả về null
					ELSE REPLACE(
							REPLACE(
								REPLACE(
									REPLACE(
										Price, 
										'$', ''
									),
									',', ''
								),
								'K', '000'
							),
							'+', ''
						 )				 -- Bỏ dấu '$', dấu '+', và thay thế 'K' bằng '000'
				END;

    ALTER TABLE [dbo].[Zillow_table]
    ALTER COLUMN Price INT;
END;

EXEC Update_Price

--Xử lý null
CREATE PROCEDURE Delete_Null
AS
BEGIN
    DELETE FROM [dbo].[Zillow_table]
    WHERE Price			  IS NULL
	   OR House_ID		 IS NULL
       OR Street_adr	 IS NULL
       OR City_adr		 IS NULL
       OR State_adr		 IS NULL
       OR Zip_Code		 IS NULL
       OR Bedrooms		 IS NULL
       OR Bathrooms		 IS NULL
       OR Square_Footage IS NULL; 
END;

EXEC Delete_Null

--2 Tạo bảng trong mô hình cơ sở dữ liệu
CREATE PROCEDURE CreateTables
AS
BEGIN
-- Tạo bảng State_table
    IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'State_table') AND type in (N'U'))
    BEGIN
        CREATE TABLE State_table (
            State_ID INT IDENTITY(1,1) PRIMARY KEY,
            State_name VARCHAR(100) NOT NULL
        );
    END

    -- Tạo bảng City_table
    IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'City_table') AND type in (N'U'))
    BEGIN
        CREATE TABLE City_table (
            City_ID INT IDENTITY(1,1) PRIMARY KEY,
            City VARCHAR(100) NOT NULL,
            State_ID INT,
            FOREIGN KEY (State_ID) REFERENCES State_table (State_ID)
        );
    END

    -- Tạo bảng House_Type_table
    IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'House_Type_table') AND type in (N'U'))
    BEGIN
        CREATE TABLE House_Type_table (
            House_Type_ID INT IDENTITY(1,1) PRIMARY KEY,
            House_Type VARCHAR(50) NOT NULL,
            Min_Price FLOAT,
            Max_Price FLOAT
        );
    END

    -- Tạo bảng Properties_table
    IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'Properties_table') AND type in (N'U'))
    BEGIN
        CREATE TABLE Properties_table (
            House_ID VARCHAR(10) PRIMARY KEY,
            Price FLOAT NOT NULL,
            Sqft FLOAT NOT NULL,
            State_ID INT,
            City_ID INT,
            House_Type_ID INT,
			Street_adr VARCHAR(200)
            FOREIGN KEY (City_ID) REFERENCES City_table(City_ID),
            FOREIGN KEY (House_Type_ID) REFERENCES House_Type_table(House_Type_ID)
        );
    END

    -- Tạo bảng Properties_Details_table
    IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'Properties_Details_table') AND type in (N'U'))
    BEGIN
        CREATE TABLE Properties_Details_table (
            Bedroom INT NOT NULL,
            Bathroom INT NOT NULL,
            House_ID VARCHAR(10),
            FOREIGN KEY (House_ID) REFERENCES Properties_table(House_ID)
        );
    END
END;
EXEC CreateTables;
	-------------
CREATE PROCEDURE InsertData
AS
BEGIN
	-- Nhập dữ liệu vào bảng State_table
    INSERT INTO State_table (State_name)
    SELECT DISTINCT state_adr
    FROM [dbo].[Zillow_table]
    WHERE state_adr NOT IN (SELECT State_name FROM State_table);

    -- Nhập dữ liệu vào bảng City_table
    INSERT INTO City_table (City, State_ID)
    SELECT DISTINCT z.City_adr, s.State_ID
    FROM [dbo].[Zillow_table] z
    JOIN State_table s ON z.State_adr = s.State_name
    WHERE NOT EXISTS (
        SELECT 1 
        FROM City_table c
        WHERE c.City = z.City_adr AND c.State_ID = s.State_ID
    );

    -- Nhập dữ liệu vào bảng House_Type_table nếu chưa có
    IF NOT EXISTS (SELECT * FROM House_Type_table)
    BEGIN
        INSERT INTO House_Type_table (House_Type, Min_Price, Max_Price)
        VALUES
            ('Entry-level House', 0, 199999),
            ('Mid-tier House', 200000, 499999),
            ('Upper Mid-tier House', 500000, 999999),
            ('Luxury House', 1000000, 4999999),
            ('Ultra-Luxury House', 5000000, 19999999),
            ('Super-Luxury House', 20000000, 99000000);
    END

    -- Nhập dữ liệu vào bảng Properties_table
    INSERT INTO Properties_table (House_ID, Price, Sqft, State_ID, City_ID, House_Type_ID,Street_adr)
    SELECT DISTINCT 
        z.House_ID,
        z.Price, 
        z.Square_Footage, 
        s.State_ID,
        c.City_ID,
        ht.House_Type_ID,
		z.Street_adr
    FROM [dbo].[Zillow_table] z
    JOIN State_table s ON z.State_adr = s.State_name
    JOIN City_table c ON z.City_adr = c.City AND s.State_ID = c.State_ID
    JOIN House_Type_table ht ON z.price BETWEEN ht.Min_Price AND ht.Max_Price
    WHERE NOT EXISTS (
        SELECT 1 
        FROM Properties_table p
        WHERE p.House_ID = z.House_ID
    );

    -- Nhập dữ liệu vào bảng Properties_Details_table
    INSERT INTO Properties_Details_table (Bedroom, Bathroom, House_ID)
    SELECT DISTINCT
        z.Bedrooms, 
        z.Bathrooms, 
        p.House_ID
    FROM [dbo].[Zillow_table] z
    JOIN Properties_table p ON z.House_ID = p.House_ID AND z.Square_Footage = p.Sqft
    WHERE NOT EXISTS (
        SELECT 1 
        FROM Properties_Details_table pd
        WHERE pd.House_ID = z.House_ID
    );
END;

EXEC InsertData;



