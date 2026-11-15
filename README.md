# FailSafeIT# FailSafe IT – relationsdatabas

Databas för kunder, konsulter och uppdrag i Microsoft SQL Server.
Kör `FailSafeIT.sql` i SSMS eller LocalDB. Skriptet droppar och återskapar databasen `FailSafeIT` varje gång, så det kan köras flera gånger med samma resultat (idempotent).

Skriptet innehåller:
- **DDL:** städar bort och skapar databasen samt alla tabeller med primärnycklar, främmande nycklar och villkor.
- **DML:** testdata med 4 kunder, 4 konsulter och 5 uppdrag.
- **Frågor A–E:** hämtning, JOIN, COUNT/GROUP BY, UPDATE och DELETE.

## ER-diagram
![ER-diagram](er-diagram.png)

Översikt (renderas automatiskt på GitHub):

```mermaid
erDiagram
    Specialitet ||--o{ Konsult : "har (1:M)"
    Kund        ||--o{ Uppdrag : "beställer (1:M)"
    Konsult     ||--o{ Uppdrag : "utför (1:M)"

    Specialitet {
        int SpecialitetId PK
        nvarchar Namn UK
    }
    Kund {
        int KundId PK
        varchar Organisationsnummer UK
        nvarchar Foretagsnamn
        nvarchar Epost
        varchar Telefonnummer
    }
    Konsult {
        int KonsultId PK
        char Personnummer UK
        nvarchar Namn
        decimal Timpris
        int SpecialitetId FK
    }
    Uppdrag {
        int UppdragId PK
        int KundId FK
        int KonsultId FK
        date Startdatum
        date Slutdatum
        nvarchar Rollbeskrivning
    }
```

## Designval

**Kopplingstabell.** Jag använder tabellen Uppdrag som kopplingstabell mellan Kund och Konsult. En kund kan anlita flera konsulter, och en konsult kan arbeta åt flera kunder. Varje rad kopplar ihop en kund med en konsult och lagrar startdatum, slutdatum och rollbeskrivning för uppdraget.

**Samma specialitet för flera konsulter.** Det går bra. Specialiteten finns en gång i tabellen för specialiteter, och flera konsulter kan hänvisa till samma specialitets-ID genom en främmande nyckel. Då slipper vi upprepa specialitetens namn.

**Personnummer är inte primärnyckel.** Jag använder ett separat konsult-ID som primärnyckel eftersom det är unikt, stabilt och oberoende av personuppgifter. Då behöver personnumret inte spridas till andra tabeller som främmande nyckel. Personnumret har ändå en UNIQUE-begränsning eftersom det ska vara unikt.

## Normalisering (3NF)

**1NF:** Alla kolumner innehåller atomära värden (ett värde per cell) och det finns inga upprepade grupper. Varje kund, konsult och uppdrag har en egen rad, och varje tabell har en primärnyckel.

**2NF:** Alla tabeller har en enkel primärnyckel (`KundId`, `KonsultId`, `UppdragId`, `SpecialitetId`), så inga attribut kan bero på en del av en sammansatt nyckel. Kund- och konsultuppgifter upprepas inte för varje uppdrag eftersom M:N-relationen är löst via tabellen `Uppdrag`.

**3NF:** Inga icke-nyckelattribut beror på andra icke-nyckelattribut. Kunduppgifter finns bara i `Kund` och konsultuppgifter bara i `Konsult`. Specialiteter ligger i en egen tabell, så att namnet lagras på ett ställe och inte kan stavas olika för olika konsulter.

## DevSecOps-reflektion

**Sec – SQL Injection:** Jag använder parametriserade frågor (prepared statements) så att indata alltid behandlas som data och aldrig som SQL-kod. Dessutom får applikationens databasanvändare minsta möjliga rättigheter (t.ex. inte `DROP`), och indata valideras på serversidan.

**Ops – prestanda vid stor datamängd:** Jag skapar index på de kolumner som söks ofta, till exempel organisationsnummer. Där finns redan ett unikt index genom `UNIQUE`-villkoret, så SQL Server kan slå upp en kund med en index seek istället för att läsa hela tabellen. Främmande nycklar i `Uppdrag` har egna index för snabba JOIN-frågor.
