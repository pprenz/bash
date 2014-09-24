USE [so1masterSQL_sept_clean]
GO
/****** Object:  StoredProcedure [hudson].[ImportRawAssessmentResults]    Script Date: 05/10/2011 15:35:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER proc [hudson].[ImportRawAssessmentResults] as

truncate table scrap.LatestRawAssessmentResults

BULK INSERT scrap.LatestRawAssessmentResults
   FROM 'j:/aspire/master.csv'
   WITH
     (
        FIRSTROW = 2,
        FIELDTERMINATOR = ',',
        ROWTERMINATOR = '\n'
     )

-- Import the Child Data from Horizon
TRUNCATE TABLE Scrap.LatestRawAssessmentResultsChild

BULK INSERT scrap.LatestRawAssessmentResultsChild
   FROM 'j:/aspire/child_pipe.csv'
   WITH
     (
        FIRSTROW = 2,
        FIELDTERMINATOR = '|',
        ROWTERMINATOR = '\n'
     )

-- Failure Point. If the file is empty, return and Fail the test
DECLARE @t_count INTEGER
SELECT @t_count=COUNT(*)
from scrap.LatestRawAssessmentResults
IF @t_count=0
    begin
        RAISERROR (N'The Assessment file sent by Horizon  is empty',10,1);
        SELECT 'The Assessment file sent by Horizon  is empty' where 1=1
        return -10
    end

-- Remove the quotes from the CSV file
update scrap.LatestRawAssessmentResults
set TEST_PLAYER_RESULTS_ID = REPLACE(TEST_PLAYER_RESULTS_ID,'"',''),
    STUDENT_ID = REPLACE(STUDENT_ID,'"',''),
    TEST_PLAYER_STUDENT_ID = REPLACE(TEST_PLAYER_STUDENT_ID,'"',''),
    ATTEMP_DATE = REPLACE(ATTEMP_DATE,'"',''),
    SCORE_DATE = REPLACE(SCORE_DATE,'"',''),
    RESCORE_FLAG = REPLACE(RESCORE_FLAG,'"',''),
    TEST_SERIAL_ID = REPLACE(TEST_SERIAL_ID,'"',''),
    TEST_PLAYER_TEST_SERIAL_ID = REPLACE(TEST_PLAYER_TEST_SERIAL_ID,'"',''),
    TEST_NAME = REPLACE(TEST_NAME,'"',''),
    ASSESSMENT_TYPE_CODE = REPLACE(ASSESSMENT_TYPE_CODE,'"',''),
    RAW_TOTAL_EARNED_SCORE = REPLACE(RAW_TOTAL_EARNED_SCORE,'"',''),
    RAW_TOTAL_POSSIBLE_SCORE = REPLACE(RAW_TOTAL_POSSIBLE_SCORE,'"',''),
    ATTEMP_MODE_CODE = REPLACE(ATTEMP_MODE_CODE,'"',''),
    PROCTOR_MODE_CODE = REPLACE(PROCTOR_MODE_CODE,'"',''),
    SCHOOL_ID = REPLACE(SCHOOL_ID,'"',''),
    TEST_PLAYER_SCHOOL_ID = REPLACE(TEST_PLAYER_SCHOOL_ID,'"',''),
    COURSE_ID = REPLACE(COURSE_ID,'"',''),
    TEST_PLAYER_COURSE_ID = REPLACE(TEST_PLAYER_COURSE_ID,'"',''),
    COURSE_SECTION_ID = REPLACE(COURSE_SECTION_ID,'"',''),
    TEST_PLAYER_COURSE_SECTION_ID = REPLACE(TEST_PLAYER_COURSE_SECTION_ID,'"',''),
    SCHOOL_YEAR = REPLACE(SCHOOL_YEAR,'"',''),
    TEACEHER_ID = REPLACE(TEACEHER_ID,'"',''),
    TEST_PLAYER_TEACEHER_ID = REPLACE(TEST_PLAYER_TEACEHER_ID,'"',''),
    STUDENT_TEST_IDENTIFIER = REPLACE(STUDENT_TEST_IDENTIFIER,'"',''),
    DELETE_DATE = REPLACE(DELETE_DATE,'"',''),
    PARENT_TEST_SERIAL_ID = REPLACE(PARENT_TEST_SERIAL_ID,'"',''),
    TEST_PLAYER_PARENT_TEST_ID = REPLACE(TEST_PLAYER_PARENT_TEST_ID,'"',''),
    COMPLETE_DATE = REPLACE(COMPLETE_DATE,'"','')
;

/* Data Cleansing Starts here */
TRUNCATE TABLE Scrap.LatestInvalidAssmntResults
/*
Rule 1:
Column F:  RESCORE_FLAG
•    If 'N' then no action required
•    If 'Y' then action required
    o    Sort Column D:  ATTEMP_DATE
        *    If today's date then no action required
        *    If date other than today then delete row
*/

INSERT INTO Scrap.LatestInvalidAssmntResults
SELECT *, 'RESCORE_FLAG is Y and Attempt Date is not today'
from scrap.LatestRawAssessmentResults
WHERE RESCORE_FLAG = 'Y'
AND DATEDIFF (day , attemp_date , GETDATE() ) <> 0
; 

DELETE FROM scrap.LatestRawAssessmentResults
WHERE RESCORE_FLAG = 'Y'
AND DATEDIFF (day , attemp_date , GETDATE() ) <> 0

/*
Rule 2:
    Column Q:  COURSE_ID
•    If format is like 228-MATH-6-605 (school-MATH-grade-section#) then no action required
•    If format is like 339-MATH-6-McHale1 (school-MATH-grade-TeacherSection) then delete row
*/

-- Make sure the TEST_PLAYER_COURSE_IDs are present in the database
DELETE FROM scrap.LatestRawAssessmentResults
WHERE TEST_PLAYER_COURSE_ID NOT IN (SELECT DISTINCT HorizonCourseID
                                    FROM dbo.SchoolSections
                                   );

-- Make sure the COURSE_ID is of the format (school-MATH-grade-section#)
-- as opposed to (school-MATH-grade-TeacherSection)
WITH sections AS
(
	SELECT DISTINCT student_id,
    REVERSE(SUBSTRING(REVERSE(COURSE_ID),0,CHARINDEX('-',REVERSE(COURSE_ID)))) section_code
	FROM scrap.LatestRawAssessmentResults
)
	DELETE from scrap.LatestRawAssessmentResults where STUDENT_ID IN
	(	SELECT STUDENT_ID
		FROM sections
		WHERE section_code NOT IN (SELECT DISTINCT SchoolSectionCode 
		FROM dbo.SchoolSections
	) 
);

/*
Rule 3
Column I:  TEST_NAME
•    If format is like 6.A.01_03 (skill_version#)then  no action required
•    If format is any other format then flag for special circumstances (ex. Diagnostics, ICA, etc.)
*/

-- Make sure the first part (Skill) is present in dbo.Skills.PICode
DELETE from scrap.LatestRawAssessmentResults
WHERE TEST_NAME NOT IN (SELECT AssessmentName
                        FROM dbo.Assessments
                        WHERE disabled = 0
                          AND AssessmentTypeId=1
                        );
/*
Rule 4
Column B:  STUDENT_ID
•    If format is like 204303606 (9 digit Student ID number) then no action required
•    If format is any other form then delete row
*/

-- Delete all the rows that contain Students that are not present in the system
DELETE FROM scrap.LatestRawAssessmentResults
WHERE STUDENT_ID NOT IN (SELECT DISTINCT studentId
                         FROM dbo.Students
                         );
						 
-- Delete all the rows that contain Student_ids that are not 9 characters.
DELETE FROM scrap.LatestRawAssessmentResults
WHERE LEN(STUDENT_ID) <> 9;
;

--Identical Student_ID, TEST_NAME, RAW_TOTAL_EARNED_SCORE, then delete the Dupliucate row
WITH dup_students as
(SELECT test_player_results_id,
        row_number() OVER (PARTITION BY STUDENT_ID, TEST_NAME, RAW_TOTAL_EARNED_SCORE ORDER BY STUDENT_ID) as rowid
 FROM scrap.LatestRawAssessmentResults
)
DELETE FROM scrap.LatestRawAssessmentResults
WHERE test_player_results_id IN (SELECT test_player_results_id FROM dup_students WHERE rowid > 1);

--Identical Student_ID, TEST_NAME, BUT DIFFERENT RAW_TOTAL_EARNED_SCORE, then delete the row with the lowest score
WITH dup_students as

(SELECT test_player_results_id,
        row_number() OVER (PARTITION BY STUDENT_ID, TEST_NAME ORDER BY RAW_TOTAL_EARNED_SCORE DESC) as rowid
 FROM scrap.LatestRawAssessmentResults)

DELETE FROM scrap.LatestRawAssessmentResults
WHERE test_player_results_id IN (SELECT test_player_results_id FROM dup_students WHERE rowid > 1);

-- Delete the rows that have aspire testIDs not in the database
DELETE FROM scrap.LatestRawAssessmentResults
WHERE TEST_PLAYER_TEST_SERIAL_ID not in (SELECT DISTINCT aspiretestid
FROM Assessments
WHERE disabled=0
AND AssessmentTypeId = 1
);

-- FAIL the test if the total num of students passed > 75 or Less than 35
WITH students_results as
(
SELECT r.*,
       CASE
           WHEN CONVERT(int, r.RAW_TOTAL_EARNED_SCORE)*100/CONVERT(int, r.RAW_TOTAL_POSSIBLE_SCORE) >= 80 THEN 1
           ELSE 0
       END AS passed
FROM scrap.LatestRawAssessmentResults r
),

tbl_pass_percent as
(
select COUNT(*)*100/(select COUNT(*) as total from scrap.LatestRawAssessmentResults) as pass_percent
from students_results
where passed = 1
group by passed
)
SELECT 'Too Many or too few Passed Students'
FROM tbl_pass_percent
WHERE pass_percent > 75 OR pass_percent < 35;