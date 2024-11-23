create database MoviesDatabase
USE Moviesdatabase

--- CLEANING DATA FROM CSV FILE

--Converting null values to zero
UPDATE MoviesDB
SET Revenue_Millions =0
where Revenue_Millions is null;

UPDATE MoviesDB
SET Metascore =0
where Metascore is null;

-- Rounding off the revenue and rating values

UPDATE MoviesDB
SET Revenue_Millions =Round(Revenue_Millions,2)

UPDATE MoviesDB
SET Rating=ROUND(Rating,1)

-- Checking any duplicate movie
select * from(
Select *, count(Title) over(partition by title) as moviecount
from MoviesDB)t
where moviecount>1;

--Results: One Movie "The Host" found which exist two times but they have different actors and directors,
--so we can rename one movie as "The Host 2" using its RANK

Update MoviesDB
Set Title ='The Host 2'
WHERE Rank=240;

Select * from MoviesDB

--- DATA CLEANED---





--CREATNG DIMENSIONS TABLE

CREATE TABLE GenreDIM(
GenreID INT IDENTITY(1,1) Primary key,
Genre NVARCHAR(50)
);

CREATE TABLE ActorDIM(
ActorID INT IDENTITY(1,1) Primary key,
Actor NVARCHAR(50)
);

CREATE TABLE DirectorDIM(
DirectorID INT IDENTITY(1,1) Primary key,
Director NVARCHAR(50)
);

CREATE TABLE YearDIM(
YearID INT IDENTITY(1,1) Primary key,
Year INT
);


--ADDING DATA INTO DIMENSIONS TABLE

INSERT INTO GenreDIM(Genre)
SELECT DISTINCT TRIM(VALUE) AS Genre
FROM MoviesDB
CROSS APPLY string_split(Genre,',');


INSERT INTO ActorDIM(Actor)
SELECT DISTINCT TRIM(VALUE) AS Actors
FROM MoviesDB
CROSS APPLY string_split (Actors,',');


INSERT INTO DirectorDIM(Director)
SELECT DISTINCT(Director)
FROM MoviesDB;


INSERT INTO YearDIM(Year)
SELECT DISTINCT(Year)
FROM MoviesDB m
ORDER BY m.Year

--- DATA INSERTED IN DIMENSION TABLES---


--Creating FACT Table (We can use rank as primary key as rank is unique in the source data for each movie)

CREATE TABLE MovieFact(
MovieID INT primary key,
Title NVARCHAR(500),
DirectorID INT,
YearID INT,
RunTime INT,
Rating FLOAT,
Votes INT,
Revenue_in_Millions INT,
MetaScore INT
FOREIGN KEY (DirectorID) REFERENCES DirectorDIM(DirectorID),
FOREIGN KEY (YearID) REFERENCES YearDIM(YearID)
)


--Adding Data into  FACT Table
INSERT INTO MovieFact(MovieID,Title,DirectorID,YearID,RunTime,Rating,Votes,Revenue_in_Millions,MetaScore)
SELECT 
m.Rank,
m.Title,
dm.DirectorID,
y.YearID,
m.Runtime_Minutes,
m.Rating,m.Votes,
m.Revenue_Millions,
m.Metascore
FROM MoviesDB m
join DirectorDIM dm
on m.Director=dm.Director
join YearDIM y
on y.Year=m.Year;

Select * from MovieFact;
-----DATA INSERTED INTO FACT TABLE---


--CREATING JUNCTION TABLES AS WE HAVE MANY TO MANY RELATIONSHIPS IN OUR DATA BETWEEN MOVIES AND GENRES & MOVIES AND ACTORS

CREATE TABLE MoviesActors(
MovieID INT,
ActorID INT,
PRIMARY KEY(MovieID,ActorID),
FOREIGN KEY (MovieID) REFERENCES MovieFact(MovieID),
FOREIGN KEY (ActorID) REFERENCES ActorDIM(ActorID)
)

CREATE TABLE MoviesGenre(
MovieID INT,
GenreID INT,
PRIMARY KEY(MovieID,GenreID),
FOREIGN KEY (MovieID) REFERENCES MovieFact(MovieID),
FOREIGN KEY (GenreID) REFERENCES GenreDIM(GenreID)
)

--INSERTING DATA INTO JUNCTION TABLES

INSERT INTO MoviesGenre(MovieID,GenreID)
SELECT MovieID,GenreID
FROM MoviesDB m
join MovieFact mf
on mf.Title=m.Title
cross apply string_split(m.Genre,',') as splitvalue
join GenreDIM g on trim(splitvalue.value)=g.Genre



Insert into MoviesActors(MovieID,ActorID)
SELECT mf.MovieID,ActorID
FROM MoviesDB m
join MovieFact mf
on mf.Title=m.Title
cross apply string_split(m.Actors,',') as splitvalue
join ActorDIM a 
on trim(splitvalue.value)=a.Actor;



-----DATA INSERTED INTO JUNCTION TABLES----



----------------------------
---CREATING SOME VIEWS NOW--
----------------------------


--Movies that have zero revenue

CREATE VIEW  N0_Revenue_Movies AS
SELECT mf.Title,
d.Director,
mf.Revenue_in_Millions,
mf.Rating,
mf.MetaScore,
mf.Votes
FROM MovieFact mf
join DirectorDIM d
on d.DirectorID=mf.DirectorID



---Number Of Movies Made By Year

CREATE VIEW  NumberOfMoviesMadeByYear AS
SELECT count(mf.Title) as NumberOfMovies,
y.Year
FROM MovieFact mf
join YearDIM y
on y.YearID=mf.YearID
group by y.Year;


---Movies Distribution by Genre

CREATE VIEW  MoviesDistributionByGenre AS
SELECT count(mf.Title) as NumberOfMovies,
g.Genre
FROM MovieFact mf
join MoviesGenre mg
on mg.MovieID=mf.MovieID
join GenreDIM g 
on g.GenreID=mg.GenreID
group by g.Genre;

--Number of movies that the actors have been cast in.

CREATE VIEW  ActorsMovieCount AS
SELECT a.Actor
,count(mf.Title) as NumberOfMovies
FROM MovieFact mf
join MoviesActors ma
on ma.MovieID=mf.MovieID
join ActorDIM a
on a.ActorID=ma.ActorID
group by a.Actor;

---Movies Distribution by Director

CREATE VIEW  MoviesDistributionByDirector AS
SELECT d.Director
,count(mf.Title) as NumberOfMovies
FROM MovieFact mf
join DirectorDIM d
on d.DirectorID=mf.DirectorID
group by d.Director;

---Movie Perfromance by Genre

CREATE VIEW  PerformanceByGenre AS
SELECT g.Genre,
Sum(mf.Revenue_in_Millions) as TotalRevenue,
Round(AVG(mf.Rating),1) as AverageRatings
FROM MovieFact mf
join MoviesGenre mg
on mg.MovieID=mf.MovieID
join GenreDIM g 
on g.GenreID=mg.GenreID
group by g.Genre;


---Movie Perfromance by Director
CREATE VIEW PerformanceByDirector AS
Select d.director,
Sum(mf.Revenue_in_Millions) as TotalRevenueInMillion,
Round(AVG(mf.Rating),1) as AverageRatings
FROM MovieFact mf
join DirectorDIM d
on d.DirectorID=mf.DirectorID
group by d.Director;

---Movies that have some revenue
CREATE VIEW MoviesWithRevenue AS
SELECT mf.Title,
d.Director,
mf.Revenue_in_Millions,
mf.Rating,
mf.MetaScore,
mf.Votes
FROM MovieFact mf
join DirectorDIM d
on d.DirectorID=mf.DirectorID
where mf.Revenue_in_Millions>0;