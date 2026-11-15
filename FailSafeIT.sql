/* =====================================================================
   FailSafe IT - relationsdatabas
   Microsoft SQL Server (LocalDB / SSMS)
   Skriptet är idempotent: det kan köras flera gånger med samma resultat.
   ===================================================================== */

/* ---------------------------------------------------------------------
   DEL 1: DDL - städa bort och skapa databasen
   --------------------------------------------------------------------- */
USE master;
GO

IF DB_ID(N'FailSafeIT') IS NOT NULL
BEGIN
    -- Kasta ut ev. öppna anslutningar så att DROP inte misslyckas
    ALTER DATABASE FailSafeIT SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE FailSafeIT;
END
GO

CREATE DATABASE FailSafeIT;
GO

USE FailSafeIT;
GO

/* ---------------------------------------------------------------------
   Tabeller
   --------------------------------------------------------------------- */

-- Specialiteter får egen tabell så att namnet lagras på ett ställe (3NF)
CREATE TABLE Specialitet
(
    SpecialitetId   INT IDENTITY(1,1) NOT NULL,
    Namn            NVARCHAR(50)      NOT NULL,
    CONSTRAINT PK_Specialitet      PRIMARY KEY (SpecialitetId),
    CONSTRAINT UQ_Specialitet_Namn UNIQUE (Namn)
);
GO

CREATE TABLE Kund
(
    KundId             INT IDENTITY(1,1) NOT NULL,
    Organisationsnummer VARCHAR(11)      NOT NULL,   -- t.ex. 556123-4567
    Foretagsnamn       NVARCHAR(100)     NOT NULL,
    Epost              NVARCHAR(100)     NOT NULL,
    Telefonnummer      VARCHAR(20)       NOT NULL,
    CONSTRAINT PK_Kund                 PRIMARY KEY (KundId),
    CONSTRAINT UQ_Kund_Organisationsnr UNIQUE (Organisationsnummer),
    CONSTRAINT CK_Kund_Epost           CHECK (Epost LIKE '%_@_%._%')
);
GO

CREATE TABLE Konsult
(
    KonsultId      INT IDENTITY(1,1) NOT NULL,
    Personnummer   CHAR(13)          NOT NULL,       -- ÅÅÅÅMMDD-NNNN
    Namn           NVARCHAR(100)     NOT NULL,
    Timpris        DECIMAL(10,2)     NOT NULL,
    SpecialitetId  INT               NOT NULL,
    CONSTRAINT PK_Konsult              PRIMARY KEY (KonsultId),
    CONSTRAINT UQ_Konsult_Personnummer UNIQUE (Personnummer),
    CONSTRAINT CK_Konsult_Timpris      CHECK (Timpris > 0),
    CONSTRAINT FK_Konsult_Specialitet  FOREIGN KEY (SpecialitetId)
        REFERENCES Specialitet (SpecialitetId)
);
GO

-- Kopplingstabell som löser M:N mellan Kund och Konsult
CREATE TABLE Uppdrag
(
    UppdragId       INT IDENTITY(1,1) NOT NULL,
    KundId          INT               NOT NULL,
    KonsultId       INT               NOT NULL,
    Startdatum      DATE              NOT NULL,
    Slutdatum       DATE              NOT NULL,
    Rollbeskrivning NVARCHAR(200)     NOT NULL,
    CONSTRAINT PK_Uppdrag         PRIMARY KEY (UppdragId),
    CONSTRAINT FK_Uppdrag_Kund    FOREIGN KEY (KundId)    REFERENCES Kund (KundId),
    CONSTRAINT FK_Uppdrag_Konsult FOREIGN KEY (KonsultId) REFERENCES Konsult (KonsultId),
    CONSTRAINT CK_Uppdrag_Datum   CHECK (Slutdatum >= Startdatum)
);
GO

-- Index på främmande nycklar (SQL Server skapar inte dessa automatiskt)
CREATE INDEX IX_Uppdrag_KundId    ON Uppdrag (KundId);
CREATE INDEX IX_Uppdrag_KonsultId ON Uppdrag (KonsultId);
GO

/* ---------------------------------------------------------------------
   DEL 2: DML - testdata
   --------------------------------------------------------------------- */
INSERT INTO Specialitet (Namn)
VALUES (N'Cybersecurity'),
       (N'DevOps'),
       (N'C# Developer'),
       (N'Databasadministration');

INSERT INTO Kund (Organisationsnummer, Foretagsnamn, Epost, Telefonnummer)
VALUES ('556123-4567', N'Nordic Bank AB',     'it@nordicbank.se',    '08-123 45 67'),
       ('556987-6543', N'Skogsindustri Syd AB','kontakt@skogsyd.se', '040-98 76 54'),
       ('556555-1212', N'Healthcare Systems AB','info@hcsystems.se', '031-55 51 21'),
       ('556777-3434', N'Kafferosteriet AB',  'hej@kafferosteriet.se','019-77 34 34');  -- saknar uppdrag (används i fråga E)

INSERT INTO Konsult (Personnummer, Namn, Timpris, SpecialitetId)
VALUES ('19850312-1234', N'Anna Lindberg',  1450.00, (SELECT SpecialitetId FROM Specialitet WHERE Namn = N'Cybersecurity')),
       ('19900724-5678', N'Erik Johansson', 1100.00, (SELECT SpecialitetId FROM Specialitet WHERE Namn = N'DevOps')),
       ('19880101-9012', N'Sara Nilsson',   1300.00, (SELECT SpecialitetId FROM Specialitet WHERE Namn = N'C# Developer')),
       ('19950615-3456', N'Omar Hassan',     950.00, (SELECT SpecialitetId FROM Specialitet WHERE Namn = N'Databasadministration'));

INSERT INTO Uppdrag (KundId, KonsultId, Startdatum, Slutdatum, Rollbeskrivning)
VALUES
 ((SELECT KundId FROM Kund WHERE Organisationsnummer = '556123-4567'),
  (SELECT KonsultId FROM Konsult WHERE Personnummer = '19850312-1234'),
  '2026-09-01', '2027-02-28', N'Säkerhetsgranskning av API-miljö'),

 ((SELECT KundId FROM Kund WHERE Organisationsnummer = '556123-4567'),
  (SELECT KonsultId FROM Konsult WHERE Personnummer = '19900724-5678'),
  '2026-10-15', '2027-03-31', N'Uppsättning av CI/CD-pipeline i Azure DevOps'),

 ((SELECT KundId FROM Kund WHERE Organisationsnummer = '556987-6543'),
  (SELECT KonsultId FROM Konsult WHERE Personnummer = '19880101-9012'),
  '2026-06-01', '2026-10-31', N'Utveckling av lagerhanteringssystem i C#'),

 ((SELECT KundId FROM Kund WHERE Organisationsnummer = '556555-1212'),
  (SELECT KonsultId FROM Konsult WHERE Personnummer = '19950615-3456'),
  '2026-11-01', '2027-01-31', N'Optimering och migrering av SQL Server-databaser'),

 ((SELECT KundId FROM Kund WHERE Organisationsnummer = '556555-1212'),
  (SELECT KonsultId FROM Konsult WHERE Personnummer = '19850312-1234'),
  '2027-01-10', '2027-04-30', N'Penetrationstest av patientportal');
GO

/* ---------------------------------------------------------------------
   DEL 3: Frågor
   --------------------------------------------------------------------- */

-- Fråga A: Konsulter med timpris över 1200 kr, dyrast först
SELECT Namn, Timpris
FROM   Konsult
WHERE  Timpris > 1200
ORDER BY Timpris DESC;
GO

-- Fråga B: Sammanställning över alla uppdrag
SELECT k.Foretagsnamn   AS Kund,
       c.Namn           AS Konsult,
       u.Startdatum,
       u.Slutdatum
FROM   Uppdrag  AS u
JOIN   Kund     AS k ON k.KundId    = u.KundId
JOIN   Konsult  AS c ON c.KonsultId = u.KonsultId
ORDER BY u.Startdatum;
GO

-- Fråga C: Antal aktiva uppdrag per kund
-- "Aktivt" = pågår idag (start <= idag <= slut).
-- LEFT JOIN med villkoret i ON gör att även kunder med 0 aktiva uppdrag visas.
SELECT k.Foretagsnamn,
       COUNT(u.UppdragId) AS AktivaUppdrag
FROM   Kund AS k
LEFT JOIN Uppdrag AS u
       ON  u.KundId     = k.KundId
       AND u.Startdatum <= CAST(GETDATE() AS DATE)
       AND u.Slutdatum  >= CAST(GETDATE() AS DATE)
GROUP BY k.KundId, k.Foretagsnamn
ORDER BY AktivaUppdrag DESC, k.Foretagsnamn;
GO

-- Fråga D: Uppdatera timpriset för en specifik konsult (Erik Johansson -> 1250 kr)
UPDATE Konsult
SET    Timpris = 1250.00
WHERE  Personnummer = '19900724-5678';

-- Verifiering
SELECT Namn, Timpris
FROM   Konsult
WHERE  Personnummer = '19900724-5678';
GO

-- Fråga E: Ta bort en kund, men bara om den inte har några uppdrag kopplade
-- (Kafferosteriet AB saknar uppdrag, så raden raderas.
--  Försök med t.ex. 556123-4567 och inget raderas.)
DELETE FROM Kund
WHERE  Organisationsnummer = '556777-3434'
  AND  NOT EXISTS (SELECT 1
                   FROM   Uppdrag
                   WHERE  Uppdrag.KundId = Kund.KundId);

-- Verifiering
SELECT KundId, Organisationsnummer, Foretagsnamn
FROM   Kund
ORDER BY KundId;
GO
