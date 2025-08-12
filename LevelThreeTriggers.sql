 #This file tracks the creation of all the triggers used at Level Three of the database
 
 #Note: Current way of handling FDI outliers is functional but inefficient. If slowdowns become a legitimate issue, look into revising, but at current db size it's fine.

DROP TRIGGER NormRawEconUpdate;
DROP TRIGGER NormRawEconInsert;
DROP TRIGGER NormAgreeUpdate;
DROP TRIGGER NormAgreeInsert;
DROP TRIGGER NormRawSecUpdate;
DROP TRIGGER NormRawSecInsert;
DROP TRIGGER NormRawPolUpdate;
DROP TRIGGER NormRawPolInsert;
DROP TRIGGER NormLogUpdate;
DROP TRIGGER NormLogInsert;
DROP TRIGGER NormLogDelete;

#Triggers for RawEconVars-------------------------------------------------------------------

#Update Trigger
DELIMITER //
CREATE TRIGGER NormRawEconUpdate
AFTER UPDATE ON RawEconVars
FOR EACH ROW

BEGIN
#First we declare our MANY variables we're going to need
#This is vastly preferable to doing max and min calcs within the SET function a million times.

DECLARE minFDITotal, maxminFDITotal, minTradeTotal, maxminTradeTotal, minAidTotal, maxminAidTotal, minTradeGDP, maxminTradeGDP, minAidGDP, maxminAidGDP,
		maxFDITotal, maxTradeTotal, maxAidTotal, maxTradeGDP, maxAidGDP DOUBLE;

#Setting up all the variables. Each two-line bundle is associated with the variables needed for one of the SETs
#Note that I do the max-min denominator calculation ahead of time rather than just generating min and max variables here. I assume it's faster this way

#We do the rev.Year = new.Year to ensure it only calculates the minimum from entries sharing a year with the updated year 
#(If you update Cuba's 2021 number, you need to recalculate the min for 2021 entries ONLY)

#Note the AND is applied for variables in which there are severe outliers (for example, North Korea's FDI pct being 100% due to unavoidable flaws in data collection)
#This AND forces it to take the *second* highest value, which, given the outliers should only be 100%, should cover things fine

SELECT MIN(FDIPctTotal) FROM RawEconVars AS rev WHERE rev.Year = new.Year INTO minFDITotal;
SELECT MAX(FDIPctTotal) FROM RawEconVars AS rev WHERE rev.Year = new.Year INTO maxFDITotal;
SET maxminFDITotal = (SELECT FDIPctTotal FROM RawEconVars AS rev WHERE rev.Year = new.Year AND FDIPctTotal < maxFDITotal ORDER BY FDIPctTotal DESC LIMIT 1 OFFSET 2);

SELECT MIN(TradePctTotal) FROM RawEconVars AS rev WHERE rev.Year = new.Year INTO minTradeTotal;
SELECT MAX(TradePctTotal) FROM RawEconVars AS rev WHERE rev.Year = new.Year INTO maxTradeTotal;
SET maxminTradeTotal = (SELECT MAX(TradePctTotal) FROM RawEconVars AS rev WHERE rev.Year = new.Year AND TradePctTotal < maxTradeTotal) - minTradeTotal;

SELECT MIN(AidPctTotal) FROM RawEconVars AS rev WHERE rev.Year = new.Year INTO minAidTotal;
SELECT MAX(AidPctTotal) FROM RawEconVars AS rev WHERE rev.Year = new.Year INTO maxAidTotal;
SET maxminAidTotal = (SELECT MAX(AidPctTotal) FROM RawEconVars AS rev WHERE rev.Year = new.Year AND AidPctTotal < maxAidTotal) - minAidTotal;

SELECT MIN(TradePctGDP) FROM RawEconVars AS rev WHERE rev.Year = new.Year INTO minTradeGDP;
SELECT MAX(TradePctGDP) FROM RawEconVars AS rev WHERE rev.Year = new.Year INTO maxTradeGDP;
SET maxminTradeGDP = (SELECT MAX(TradePctGDP) FROM RawEconVars AS rev WHERE rev.Year = new.Year AND TradePctGDP < maxTradeGDP) - minTradeGDP;

SELECT MIN(AidPctGDP) FROM RawEconVars AS rev WHERE rev.Year = new.Year INTO minAidGDP;
SELECT MAX(AidPctGDP) FROM RawEconVars AS rev WHERE rev.Year = new.Year INTO maxAidGDP;
SET maxminAidGDP = (SELECT MAX(AidPctGDP) FROM RawEconVars AS rev WHERE rev.Year = new.Year AND AidPctGDP < maxAidGDP) - minAidGDP;

#Now we actually update things. This does one large update to avoid on number of times scanning the table, even if it results in unnecessary replacements.

#This probably needs an index because this is a beefy scan it has to do. LOOK INTO THIS!!! <--------------
UPDATE NormEconVars AS nev

SET 
nev.FDIPctTotal = 
CASE
	WHEN maxminFDITotal = 0 OR maxminFDITotal = NULL
	THEN 0
    WHEN new.FDIPctTotal = maxFDITotal OR new.FDIPctTotal > (SELECT FDIPctTotal FROM RawEconVars AS rev WHERE rev.Year = new.Year AND FDIPctTotal < maxFDITotal ORDER BY FDIPctTotal DESC LIMIT 1 OFFSET 2)
    THEN 1
	ELSE ((new.FDIPctTotal - minFDITotal) / maxminFDITotal)
END,
nev.TradePctTotal = 
CASE
	WHEN maxminTradeTotal = 0 OR  maxminTradeTotal = NULL
	THEN 0
    WHEN new.TradePctTotal = maxTradeTotal
    THEN 1
	ELSE ((new.TradePctTotal - minTradeTotal) / maxminTradeTotal)
END,
nev.AidPctTotal = 
CASE
	WHEN maxminAidTotal = 0 OR maxminAidTotal = NULL
	THEN 0
    WHEN new.AidPctTotal = maxAidTotal
    THEN 1
	ELSE ((new.AidPctTotal - minAidTotal) / maxminAidTotal)
END,
nev.TradePctGDP = 
CASE
	WHEN maxminTradeGDP = 0 OR maxminTradeGDP = NULL
	THEN 0
    WHEN new.TradePctGDP = maxTradeGDP
    THEN 1
    ELSE ((new.TradePctGDP - minTradeGDP) / maxminTradeGDP)
END,
nev.AidPctGDP =
CASE
	WHEN maxminAidGDP = 0 OR maxminAidGDP = NULL
	THEN 0
    WHEN new.AidPctGDP = maxAidGDP
    THEN 1
    ELSE ((new.AidPctGDP - minAidGDP) / maxminAidGDP)
END

WHERE nev.CountryName = new.CountryName AND nev.Year = new.Year AND nev.LocKey = new.LocKey;

END//

#Insert Trigger
DELIMITER //
CREATE TRIGGER NormRawEconInsert
AFTER INSERT ON RawEconVars
FOR EACH ROW

BEGIN

DECLARE minFDITotal, maxminFDITotal, minTradeTotal, maxminTradeTotal, minAidTotal, maxminAidTotal, minTradeGDP, maxminTradeGDP, minAidGDP, maxminAidGDP,
		maxFDITotal, maxTradeTotal, maxAidTotal, maxTradeGDP, maxAidGDP DOUBLE;

#Refer to the update trigger for documentation on what's going on here

SELECT MIN(FDIPctTotal) FROM RawEconVars AS rev WHERE rev.Year = new.Year INTO minFDITotal;
SELECT MAX(FDIPctTotal) FROM RawEconVars AS rev WHERE rev.Year = new.Year INTO maxFDITotal;
SET maxminFDITotal = (SELECT FDIPctTotal FROM RawEconVars AS rev WHERE rev.Year = new.Year AND FDIPctTotal < maxFDITotal ORDER BY FDIPctTotal DESC LIMIT 1 OFFSET 2);

SELECT MIN(TradePctTotal) FROM RawEconVars AS rev WHERE rev.Year = new.Year INTO minTradeTotal;
SELECT MAX(TradePctTotal) FROM RawEconVars AS rev WHERE rev.Year = new.Year INTO maxTradeTotal;
SET maxminTradeTotal = (SELECT MAX(TradePctTotal) FROM RawEconVars AS rev WHERE rev.Year = new.Year AND TradePctTotal < maxTradeTotal) - minTradeTotal;

SELECT MIN(AidPctTotal) FROM RawEconVars AS rev WHERE rev.Year = new.Year INTO minAidTotal;
SELECT MAX(AidPctTotal) FROM RawEconVars AS rev WHERE rev.Year = new.Year INTO maxAidTotal;
SET maxminAidTotal = (SELECT MAX(AidPctTotal) FROM RawEconVars AS rev WHERE rev.Year = new.Year AND AidPctTotal < maxAidTotal) - minAidTotal;

SELECT MIN(TradePctGDP) FROM RawEconVars AS rev WHERE rev.Year = new.Year INTO minTradeGDP;
SELECT MAX(TradePctGDP) FROM RawEconVars AS rev WHERE rev.Year = new.Year INTO maxTradeGDP;
SET maxminTradeGDP = (SELECT MAX(TradePctGDP) FROM RawEconVars AS rev WHERE rev.Year = new.Year AND TradePctGDP < maxTradeGDP) - minTradeGDP;

SELECT MIN(AidPctGDP) FROM RawEconVars AS rev WHERE rev.Year = new.Year INTO minAidGDP;
SELECT MAX(AidPctGDP) FROM RawEconVars AS rev WHERE rev.Year = new.Year INTO maxAidGDP;
SET maxminAidGDP = (SELECT MAX(AidPctGDP) FROM RawEconVars AS rev WHERE rev.Year = new.Year AND AidPctGDP < maxAidGDP) - minAidGDP;

INSERT INTO NormEconVars (CountryName, Year, LocKey, FDIPctTotal, TradePctTotal, TradePctGDP, AidPctTotal, AidPctGDP)
VALUES
(
new.CountryName, 
new.Year, 
new.LocKey,
CASE
	WHEN maxminFDITotal = 0 OR maxminFDITotal = NULL
	THEN 0
    WHEN new.FDIPctTotal = maxFDITotal OR new.FDIPctTotal > (SELECT FDIPctTotal FROM RawEconVars AS rev WHERE rev.Year = new.Year AND FDIPctTotal < maxFDITotal ORDER BY FDIPctTotal DESC LIMIT 1 OFFSET 2)
    THEN 1
	ELSE ((new.FDIPctTotal - minFDITotal) / maxminFDITotal)
END,
CASE
	WHEN maxminTradeTotal = 0 OR maxminTradeTotal = NULL
	THEN 0
    WHEN new.TradePctTotal = maxTradeTotal
    THEN 1
	ELSE ((new.TradePctTotal - minTradeTotal) / maxminTradeTotal)
END,
CASE
	WHEN maxminTradeGDP = 0 OR maxminTradeGDP = NULL
	THEN 0
    WHEN new.TradePctGDP = maxTradeGDP
    THEN 1
    ELSE ((new.TradePctGDP - minTradeGDP) / maxminTradeGDP)
END,
CASE
	WHEN maxminAidTotal = 0 OR maxminAidTotal = NULL
	THEN 0
    WHEN new.AidPctTotal = maxAidTotal
    THEN 1
	ELSE ((new.AidPctTotal - minAidTotal) / maxminAidTotal)
END,
CASE
	WHEN maxminAidGDP = 0 OR maxminAidGDP = NULL
	THEN 0
    WHEN new.AidPctGDP = maxAidGDP
    THEN 1
    ELSE ((new.AidPctGDP - minAidGDP) / maxminAidGDP)
END
)
ON DUPLICATE KEY
UPDATE 
FDIPctTotal = 
CASE
	WHEN maxminFDITotal = 0 OR maxminFDITotal = NULL
	THEN 0
    WHEN new.FDIPctTotal = maxFDITotal OR new.FDIPctTotal > (SELECT FDIPctTotal FROM RawEconVars AS rev WHERE rev.Year = new.Year AND FDIPctTotal < maxFDITotal ORDER BY FDIPctTotal DESC LIMIT 1 OFFSET 2)
    THEN 1
	ELSE ((new.FDIPctTotal - minFDITotal) / maxminFDITotal)
END,
TradePctTotal = 
CASE
	WHEN maxminTradeTotal = 0 OR maxminTradeTotal = NULL
	THEN 0
    WHEN new.TradePctTotal = maxTradeTotal
    THEN 1
	ELSE ((new.TradePctTotal - minTradeTotal) / maxminTradeTotal)
END,
AidPctTotal = 
CASE
	WHEN maxminAidTotal = 0 OR maxminAidTotal = NULL
	THEN 0
    WHEN new.AidPctTotal = maxAidTotal
    THEN 1
	ELSE ((new.AidPctTotal - minAidTotal) / maxminAidTotal)
END,
TradePctGDP = 
CASE
	WHEN maxminTradeGDP = 0 OR maxminTradeGDP = NULL
	THEN 0
    WHEN new.TradePctGDP = maxTradeGDP
    THEN 1
    ELSE ((new.TradePctGDP - minTradeGDP) / maxminTradeGDP)
END,
AidPctGDP =
CASE
	WHEN maxminAidGDP = 0 OR maxminAidGDP = NULL
	THEN 0
    WHEN new.AidPctGDP = maxAidGDP
    THEN 1
    ELSE ((new.AidPctGDP - minAidGDP) / maxminAidGDP)
END
;

END//
DELIMITER ;

#Delete Trigger
DELIMITER //
CREATE TRIGGER NormRawEconDelete
AFTER DELETE ON RawEconVars
FOR EACH ROW 

UPDATE NormEconVars AS nev
SET 

nev.FDIPctTotal = NULL,
nev.TradePctTotal = NULL,
nev.AidPctTotal = NULL,
nev.TradePctGDP = NULL,
nev.AidPctGDP = NULL

WHERE nev.CountryName = old.CountryName AND nev.Year = old.Year AND nev.LocKey = old.LocKey;
DELIMITER ;

#Triggers for TradeAgreeFinal-------------------------------------------------------------------

#Update Trigger
DELIMITER //
CREATE TRIGGER NormAgreeUpdate
AFTER UPDATE ON TradeAgreeFinal
FOR EACH ROW

BEGIN

DECLARE minAgreeScore, maxminAgreeScore DOUBLE;

SELECT MIN(AgreeScore) FROM TradeAgreeFinal AS taf WHERE taf.Year = new.Year INTO minAgreeScore;
SET maxminAgreeScore = (SELECT MAX(AgreeScore) FROM TradeAgreeFinal AS taf WHERE taf.Year = new.Year) - minAgreeScore;

UPDATE
NormEconVars AS nev
SET
nev.AgreeScore = 
CASE
WHEN maxminAgreeScore = 0 OR maxminAgreeScore = NULL
THEN 0
ELSE ((new.AgreeScore - minAgreeScore) / maxminAgreeScore)
END

WHERE
nev.CountryName = new.CountryName AND nev.Year = new.Year AND nev.LocKey = new.LocKey;

END//
DELIMITER ;

#Insert Trigger
DELIMITER //
CREATE TRIGGER NormAgreeInsert
AFTER INSERT ON TradeAgreeFinal
FOR EACH ROW

BEGIN

DECLARE minAgreeScore, maxminAgreeScore DOUBLE;

SELECT MIN(AgreeScore) FROM TradeAgreeFinal AS taf WHERE taf.Year = new.Year INTO minAgreeScore;
SET maxminAgreeScore = (SELECT MAX(AgreeScore) FROM TradeAgreeFinal AS taf WHERE taf.Year = new.Year) - minAgreeScore;

INSERT INTO NormEconVars(CountryName, Year, LocKey, AgreeScore)
VALUES(
new.CountryName,
new.Year,
new.LocKey,
CASE
	WHEN maxminAgreeScore = 0 OR maxminAgreeScore = NULL
	THEN 0
	ELSE ((new.AgreeScore - minAgreeScore) / maxminAgreeScore)
END
)
ON DUPLICATE KEY
UPDATE
AgreeScore = 
CASE
	WHEN maxminAgreeScore = 0 OR maxminAgreeScore = NULL
	THEN 0
	ELSE ((new.AgreeScore - minAgreeScore) / maxminAgreeScore)
END;

END //
DELIMITER ;

#Delete Trigger
DELIMITER //
CREATE TRIGGER NormAgreeDelete
AFTER DELETE ON TradeAgreeFinal
FOR EACH ROW

BEGIN

UPDATE NormEconVars AS nev
SET nev.AgreeScore = NULL
WHERE nev.CountryName = old.CountryName AND nev.Year = old.Year AND nev.LocKey = old.LocKey;

END //
DELIMITER ;

#Triggers for RawSecVars-------------------------------------------------------------------

#Update Trigger
DELIMITER //
CREATE TRIGGER NormRawSecUpdate
AFTER UPDATE ON RawSecVars
FOR EACH ROW

BEGIN

DECLARE minArmsPctTotal, maxminArmsPctTotal, maxArmsPctTotal DOUBLE;

SELECT MIN(ArmsPctTotal) FROM RawSecVars AS rsv WHERE rsv.Year = new.Year INTO minArmsPctTotal;
SELECT MAX(ArmsPctTotal) FROM RawSecVars AS rsv WHERE rsv.Year = new.Year INTO maxArmsPctTotal;
SET maxminArmsPctTotal = (SELECT MAX(ArmsPctTotal) FROM RawSecVars AS rsv WHERE rsv.Year = new.Year AND ArmsPctTotal < maxArmsPctTotal) - minArmsPctTotal;

UPDATE
NormSecVars AS nsv
SET
nsv.ArmsPctTotal = 
CASE
	WHEN maxminArmsPctTotal = 0 OR maxminArmsPctTotal = NULL
	THEN 0
    WHEN new.ArmsPctTotal = maxArmsPctTotal
    THEN 1
	ELSE ((new.ArmsPctTotal - minArmsPctTotal) / maxminArmsPctTotal)
END
WHERE
nsv.CountryName = new.CountryName AND nsv.Year = new.Year AND nsv.LocKey = new.LocKey;

END//
DELIMITER ;

#Insert Trigger
DELIMITER //
CREATE TRIGGER NormRawSecInsert
AFTER INSERT ON RawSecVars
FOR EACH ROW

BEGIN

DECLARE minArmsPctTotal, maxminArmsPctTotal, maxArmsPctTotal DOUBLE;

SELECT MIN(ArmsPctTotal) FROM RawSecVars AS rsv WHERE rsv.Year = new.Year INTO minArmsPctTotal;
SELECT MAX(ArmsPctTotal) FROM RawSecVars AS rsv WHERE rsv.Year = new.Year INTO maxArmsPctTotal;
SET maxminArmsPctTotal = (SELECT MAX(ArmsPctTotal) FROM RawSecVars AS rsv WHERE rsv.Year = new.Year AND ArmsPctTotal < maxArmsPctTotal) - minArmsPctTotal;

INSERT INTO NormSecVars (CountryName, Year, LocKey, ArmsPctTotal)
VALUES(
new.CountryName,
new.Year,
new.LocKey,
CASE
	WHEN maxminArmsPctTotal = 0 OR maxminArmsPctTotal = NULL
	THEN 0
    WHEN new.ArmsPctTotal = maxArmsPctTotal
    THEN 1
	ELSE ((new.ArmsPctTotal - minArmsPctTotal) / maxminArmsPctTotal)
END
)
ON DUPLICATE KEY
UPDATE
ArmsPctTotal = 
CASE
	WHEN maxminArmsPctTotal = 0 OR maxminArmsPctTotal = NULL
	THEN 0
    WHEN new.ArmsPctTotal = maxArmsPctTotal
    THEN 1
	ELSE ((new.ArmsPctTotal - minArmsPctTotal) / maxminArmsPctTotal)
END;

END//
DELIMITER ;

#Delete Trigger
DELIMITER //
CREATE TRIGGER NormRawSecDelete
AFTER DELETE ON RawSecVars
FOR EACH ROW

BEGIN

UPDATE NormSecVars AS nsv
SET
nsv.ArmsPctTotal = NULL
WHERE nsv.CountryName = old.CountryName AND nsv.Year = old.Year AND nsv.LocKey = old.LocKey;

END//
DELIMITER ;

#Triggers for MiscSecVars-------------------------------------------------------------------

#Update Trigger
DELIMITER //
CREATE TRIGGER NormMiscSecUpdate
AFTER UPDATE ON MiscSecVars
FOR EACH ROW

BEGIN

#BaseNum does not actually get "normalized", but since it does have *something* applied to it prior to weighting, this functionality is lumped in as a type of normalization
#Is assigned the value of 1 if 0 < rsv.BaseNum <= 2, and value of 1.25 if 2 < rsv.BaseNum
#Basically serves as a way to acknowledge a high number of bases = substantial influence without devaluing the major influence one or two bases is still indicative of

UPDATE
NormSecVars AS nsv
SET
nsv.BaseNum = 
CASE
	WHEN 0 < new.BaseNum AND new.BaseNum <= 2
		THEN #OMITTED FOR DATA SECURITY
    WHEN new.BaseNum > 2 
		THEN #OMITTED FOR DATA SECURITY
    ELSE #OMITTED FOR DATA SECURITY 
    END
WHERE
nsv.CountryName = new.CountryName AND nsv.Year = new.Year AND nsv.LocKey = new.LocKey;

END//
DELIMITER ;

#Insert Trigger
DELIMITER //
CREATE TRIGGER NormMiscSecInsert
AFTER INSERT ON MiscSecVars
FOR EACH ROW

BEGIN

INSERT INTO NormSecVars (CountryName, Year, LocKey, BaseNum)
VALUES
(
new.CountryName,
new.Year,
new.LocKey,
CASE
	WHEN 0 < new.BaseNum AND new.BaseNum <= 2
		THEN #OMITTED FOR DATA SECURITY
    WHEN new.BaseNum > 2 
		THEN #OMITTED FOR DATA SECURITY
    ELSE #OMITTED FOR DATA SECURITY 
    END
)
ON DUPLICATE KEY
UPDATE
BaseNum =
CASE
	WHEN 0 < new.BaseNum AND new.BaseNum <= 2
		THEN #OMITTED FOR DATA SECURITY
    WHEN new.BaseNum > 2 
		THEN #OMITTED FOR DATA SECURITY
    ELSE #OMITTED FOR DATA SECURITY 
    END
;

END//
DELIMITER ;

#Delete Trigger
DELIMITER //
CREATE TRIGGER NormMiscSecDelete
AFTER DELETE ON MiscSecVars
FOR EACH ROW

BEGIN

UPDATE NormSecVars AS nsv
SET
nsv.BaseNum = NULL

WHERE nsv.CountryName = old.CountryName AND nsv.Year = old.Year AND nsv.LocKey = old.LocKey;

END//
DELIMITER ;

#Triggers for RawPolVars-------------------------------------------------------------------

#Update Trigger
DELIMITER //
CREATE TRIGGER NormRawPolUpdate
AFTER UPDATE ON RawPolVars
FOR EACH ROW

BEGIN

DECLARE minSummitSum, maxminSummitSum, minUNVotePct, maxminUNVotePct, trueminUNVotePct DOUBLE;

SELECT MIN(SummitSum) FROM RawPolVars AS rpv WHERE rpv.Year = new.Year INTO minSummitSum;
SET maxminSummitSum = (SELECT MAX(SummitSum) FROM RawPolVars AS rpv WHERE rpv.Year = new.Year) - minSummitSum;

#Note that the AND here is actually avoiding the issue of a *MIN* breakage. These were caused by a few countries completely lacking data
#Keep in mind that 0s are fine in variables that already have very low values or 0s naturally. In UN and TotalTrade, however, values shouldn't normally be near 0

SET trueminUNVotePct = (SELECT MIN(UNVotePct) FROM RawPolVars AS rpv WHERE rpv.Year = new.Year);
SELECT MIN(UNVotePct) FROM RawPolVars AS rpv WHERE rpv.Year = new.Year AND UNVotePct > trueminUNVotePct INTO minUNVotePct;
SET maxminUNVotePct = (SELECT MAX(UNVotePct) FROM RawPolVars AS rpv WHERE rpv.Year = new.Year) - minUNVotePct;

UPDATE
NormPolVars AS npv
SET
npv.SummitSum = 
CASE
	WHEN maxminSummitSum = 0 OR maxminSummitSum = NULL OR new.SummitSum IS NULL
	THEN 0
	ELSE ((new.SummitSum - minSummitSum) / maxminSummitSum)
END,
npv.UNVotePct = 
CASE
	WHEN maxminUNVotePct = 0 OR maxminUNVotePct = NULL OR new.UNVotePct = trueminUNVotePct
	THEN 0
	ELSE ((new.UNVotePct - minUNVotePct) / maxminUNVotePct)
END
WHERE
npv.CountryName = new.CountryName AND npv.Year = new.Year AND npv.LocKey = new.LocKey;

END//

#Insert Trigger
DELIMITER //
CREATE TRIGGER NormRawPolInsert
AFTER INSERT ON RawPolVars
FOR EACH ROW

BEGIN

DECLARE minSummitSum, maxminSummitSum, minUNVotePct, maxminUNVotePct, trueminUNVotePct DOUBLE;

SELECT MIN(SummitSum) FROM RawPolVars AS rpv WHERE rpv.Year = new.Year INTO minSummitSum;
SET maxminSummitSum = (SELECT MAX(SummitSum) FROM RawPolVars AS rpv WHERE rpv.Year = new.Year) - minSummitSum;

SET trueminUNVotePct = (SELECT MIN(UNVotePct) FROM RawPolVars AS rpv WHERE rpv.Year = new.Year);
SELECT MIN(UNVotePct) FROM RawPolVars AS rpv WHERE rpv.Year = new.Year AND UNVotePct > trueminUNVotePct INTO minUNVotePct;
SET maxminUNVotePct = (SELECT MAX(UNVotePct) FROM RawPolVars AS rpv WHERE rpv.Year = new.Year) - minUNVotePct;

INSERT INTO NormPolVars (CountryName, Year, LocKey, SummitSum, UNVotePct)
VALUES(
new.CountryName,
new.Year,
new.LocKey,
CASE
	WHEN maxminSummitSum = 0 OR maxminSummitSum = NULL
	THEN 0
	WHEN new.SummitSum IS NULL
    THEN 0
	ELSE ((new.SummitSum - minSummitSum) / maxminSummitSum)
END,
CASE
	WHEN maxminUNVotePct = 0 OR maxminUNVotePct = NULL OR new.UNVotePct = trueminUNVotePct
	THEN 0
	ELSE ((new.UNVotePct - minUNVotePct) / maxminUNVotePct)
END
)
ON DUPLICATE KEY
UPDATE
SummitSum = 
CASE
	WHEN maxminSummitSum = 0 OR maxminSummitSum = NULL
	THEN 0
	ELSE ((new.SummitSum - minSummitSum) / maxminSummitSum)
END,
UNVotePct = 
CASE
	WHEN maxminUNVotePct = 0 OR maxminUNVotePct = NULL OR new.UNVotePct = trueminUNVotePct
	THEN 0
	ELSE ((new.UNVotePct - minUNVotePct) / maxminUNVotePct)
END;
END//
DELIMITER ;

#Delete Trigger
DELIMITER //
CREATE TRIGGER NormRawPolDelete
AFTER DELETE ON RawPolVars
FOR EACH ROW

BEGIN

UPDATE NormPolVars AS npv
SET
npv.SummitSum = NULL,
npv.UNVotePct = NULL
WHERE
npv.CountryName = old.CountryName AND npv.Year = old.Year AND npv.LocKey = old.LocKey;

END//
DELIMITER ;

#Triggers for AllVarsLog-------------------------------------------------------------------

#Update Trigger
DELIMITER //
CREATE TRIGGER NormLogUpdate
AFTER UPDATE ON AllVarsLog
FOR EACH ROW

BEGIN

DECLARE minFDIGDP, maxminFDIGDP, minArmsValue, maxminArmsValue, minSisterCity, maxminSisterCity, minTotalTrade, maxminTotalTrade, trueminTotalTrade DOUBLE;

SELECT MIN(FDIPctGDPLog) FROM AllVarsLog AS avl WHERE avl.Year = new.Year INTO minFDIGDP;
SET maxminFDIGDP = (SELECT MAX(FDIPctGDPLog) FROM AllVarsLog AS avl WHERE avl.Year = new.Year) - minFDIGDP;

SELECT MIN(ArmsValueLog) FROM AllVarsLog AS avl WHERE avl.Year = new.Year INTO minArmsValue;
SET maxminArmsValue = (SELECT MAX(ArmsValueLog) FROM AllVarsLog AS avl WHERE avl.Year = new.Year) - minArmsValue;

SELECT MIN(SisterCityLog) FROM AllVarsLog AS avl WHERE avl.Year = new.Year INTO minSisterCity;
SET maxminSisterCity = (SELECT MAX(SisterCityLog) FROM AllVarsLog AS avl WHERE avl.Year = new.Year) - minSisterCity;

SELECT MIN(TotalTradeLog) FROM AllVarsLog AS avl WHERE avl.Year = new.Year AND TotalTradeLog > (SELECT MIN(TotalTradeLog) FROM AllVarsLog) INTO minTotalTrade;
SET maxminTotalTrade = (SELECT MAX(TotalTradeLog) FROM AllVarsLog AS avl WHERE avl.Year = new.Year) - minTotalTrade;

#Handles NEV's log values
UPDATE 
NormEconVars AS nev
SET 
nev.FDIPctGDP = 
CASE
	WHEN maxminFDIGDP = 0 OR maxminFDIGDP = NULL
	THEN 0
	ELSE ((new.FDIPctGDPLog - minFDIGDP) / maxminFDIGDP)
END,
nev.TotalTrade = 
CASE
	WHEN maxminTotalTrade = 0 OR maxminTotalTrade = NULL
    THEN 0
    ELSE ((new.TotalTradeLog - minTotalTrade) / maxminTotalTrade)
END
WHERE 
nev.CountryName = new.CountryName AND nev.Year = new.Year AND nev.LocKey = new.LocKey;

#Handles NSV's log value
UPDATE 
NormSecVars AS nsv
SET 
nsv.ArmsValue = 
CASE
	WHEN maxminArmsValue = 0 OR maxminArmsValue = NULL
	THEN 0
	ELSE ((new.ArmsValueLog - minArmsValue) / maxminArmsValue)
END
WHERE 
nsv.CountryName = new.CountryName AND nsv.Year = new.Year AND nsv.LocKey = new.LocKey;

#Handles NPV's log value
UPDATE NormPolVars AS npv
SET
npv.SisterCity = 
CASE
	WHEN maxminSisterCity = 0 OR maxminSisterCity = NULL
	THEN 0
	ELSE ((new.SisterCityLog - minSisterCity) / maxminSisterCity)
END
WHERE
npv.CountryName = new.CountryName AND npv.Year = new.Year AND npv.LocKey = new.LocKey;

END//
DELIMITER ;

#Insert Trigger
DELIMITER //
CREATE TRIGGER NormLogInsert
AFTER INSERT ON AllVarsLog
FOR EACH ROW

BEGIN

DECLARE minFDIGDP, maxminFDIGDP, minArmsValue, maxminArmsValue, minSisterCity, maxminSisterCity, minTotalTrade, maxminTotalTrade DOUBLE;

SELECT MIN(FDIPctGDPLog) FROM AllVarsLog AS avl WHERE avl.Year = new.Year INTO minFDIGDP;
SET maxminFDIGDP = (SELECT MAX(FDIPctGDPLog) FROM AllVarsLog AS avl WHERE avl.Year = new.Year) - minFDIGDP;

SELECT MIN(ArmsValueLog) FROM AllVarsLog AS avl WHERE avl.Year = new.Year INTO minArmsValue;
SET maxminArmsValue = (SELECT MAX(ArmsValueLog) FROM AllVarsLog AS avl WHERE avl.Year = new.Year) - minArmsValue;

SELECT MIN(SisterCityLog) FROM AllVarsLog AS avl WHERE avl.Year = new.Year INTO minSisterCity;
SET maxminSisterCity = (SELECT MAX(SisterCityLog) FROM AllVarsLog AS avl WHERE avl.Year = new.Year) - minSisterCity;

SELECT MIN(TotalTradeLog) FROM AllVarsLog AS avl WHERE avl.Year = new.Year AND TotalTradeLog > (SELECT MIN(TotalTradeLog) FROM AllVarsLog) INTO minTotalTrade;
SET maxminTotalTrade = (SELECT MAX(TotalTradeLog) FROM AllVarsLog AS avl WHERE avl.Year = new.Year) - minTotalTrade;

#Handles NEV's log value
INSERT INTO NormEconVars (CountryName, Year, LocKey, FDIPctGDP, TotalTrade)
VALUES
(
new.CountryName, 
new.Year, 
new.LocKey,
CASE
	WHEN maxminFDIGDP = 0 OR maxminFDIGDP = NULL
	THEN 0
	ELSE ((new.FDIPctGDPLog - minFDIGDP) / maxminFDIGDP)
END,
CASE
	WHEN maxminTotalTrade = 0 OR maxminTotalTrade = NULL
    THEN 0
    ELSE ((new.TotalTradeLog - minTotalTrade) / maxminTotalTrade)
END
)
ON DUPLICATE KEY
UPDATE 
FDIPctGDP = 
CASE
	WHEN maxminFDIGDP = 0 OR maxminFDIGDP = NULL
	THEN 0
	ELSE ((new.FDIPctGDPLog - minFDIGDP) / maxminFDIGDP)
END,
TotalTrade = 
CASE
	WHEN maxminTotalTrade = 0 OR maxminTotalTrade = NULL
    THEN 0
    ELSE ((new.TotalTradeLog - minTotalTrade) / maxminTotalTrade)
END;

#Handles NSV's log value
INSERT INTO NormSecVars (CountryName, Year, LocKey, ArmsValue)
VALUES
(
new.CountryName,
new.Year,
new.LocKey,
CASE
	WHEN maxminArmsValue = 0 OR maxminArmsValue = NULL
	THEN 0
	ELSE ((new.ArmsValueLog - minArmsValue) / maxminArmsValue)
END
)
ON DUPLICATE KEY
UPDATE
ArmsValue = 
CASE
	WHEN maxminArmsValue = 0 OR maxminArmsValue = NULL
	THEN 0
	ELSE ((new.ArmsValueLog - minArmsValue) / maxminArmsValue)
END;

#Handles NPV's log value
INSERT INTO NormPolVars (CountryName, Year, LocKey, SisterCity)
VALUES
(
new.CountryName,
new.Year,
new.LocKey,
CASE
	WHEN maxminSisterCity = 0 OR maxminSisterCity = NULL
	THEN 0
	ELSE ((new.SisterCityLog - minSisterCity) / maxminSisterCity)
END
)
ON DUPLICATE KEY 
UPDATE
SisterCity = 
CASE
	WHEN maxminSisterCity = 0 OR maxminSisterCity = NULL
	THEN 0
	ELSE ((new.SisterCityLog - minSisterCity) / maxminSisterCity)
END;

END//
DELIMITER ;

#Delete Trigger
DELIMITER //
CREATE TRIGGER NormLogDelete
AFTER DELETE ON AllVarsLog
FOR EACH ROW

BEGIN

#Handles NEV's log value
UPDATE NormEconVars AS nev
SET 
nev.FDIPctGDP = NULL,
nev.TotalTrade = NULL
WHERE 
nev.CountryName = old.CountryName AND nev.Year = old.Year AND nev.LocKey = old.LocKey;

#Handles NSV's log value
UPDATE NormSecVars AS nsv
SET
nsv.ArmsValue = NULL
WHERE
nsv.CountryName = old.CountryName AND nsv.Year = old.Year AND nsv.LocKey = old.LocKey;

#Handles NPV's log value
UPDATE NormPolVars AS npv
SET
npv.SisterCity = NULL
WHERE
npv.CountryName = old.CountryName AND npv.Year = old.Year AND npv.LocKey = old.LocKey;

END//
DELIMITER ;
