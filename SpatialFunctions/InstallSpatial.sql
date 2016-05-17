-- ***********************************************************************************************
-- uncomment these lines if you need to create view for spatial functions and/or build spatial 
/*
BEGIN TRY DROP VIEW ObjectList END TRY BEGIN CATCH END CATCH
go
CREATE VIEW ObjectList AS SELECT objID, ra, dec, Spatial FROM  dbo.CatalogRecord
go

BEGIN TRY DROP PROCEDURE spComputeSpatialPoints END TRY BEGIN CATCH END CATCH
GO
CREATE PROCEDURE spComputeSpatialPoints		
-- Computes spatial field for catalog positions
AS BEGIN
	UPDATE wiserecord SET Spatial=geography::Point(STR(dec,12,8),STR(ra,12,8),104001) -- WHERE Spatial is NULL
END
GO
--EXEC spComputeSpatialPoints
GO

BEGIN TRY DROP PROCEDURE spBuildSpatialIndex END TRY BEGIN CATCH END CATCH
GO
CREATE PROCEDURE spBuildSpatialIndex		
-- Builds spatial index
-- Requires editing if Main Table is not called CatalogRecord
AS BEGIN
	CREATE SPATIAL INDEX IDX_spatial_ObjectList
	ON MergedCatalog(Spatial)
	USING GEOGRAPHY_AUTO_GRID 
	--WITH (GRIDS=(HIGH,HIGH,HIGH,HIGH))
END
GO
--EXEC spBuildSpatialIndex
GO
*/
--*************************************************************************************************************
-- Step 3 --
/*******************************************************************************************************************************
-- Step 4 --
Routines to install Spatial functions in SQLserver database

Requirements :
The main table must contain objID, RA, DEC and Spatial columns and called CatalogRecord (or you edit SP below)
The objID column should be unique & primary key
The spatial column should be indexed (SP included)
A view called ObjectList should be created containing objID, RA, DEC, Spatial (used by search functions)

Stored procedure spComputeSpatialPoints will fill the spatial column for catalog positions
Stored procedures for computing spatial for footprints are custom-coded.
Stored procedure spBuildSpatialIndex will create index ***You MUST edit this with Table Name for your Database***

RA & DEC & Radius units are degrees
Function fSearchBox(RAmin,DECmin,RAmax,DECmax) will return objID for objects whose spatial entry intersects the box
Function fSearchCircle(RAcen,DECcen,Radius) will return objID for objects whose spatial entry intersects the circle
Function fSearchCircleDistance(RAcen,DECcen,Radius) will return objID for objects whose spatial entry intersects the circle and distance from center in arcsec
Function ConvertWKTtoSTCS will convert geospatial WKT to IVOA STC-S
Function ConvertSTCStoWKT will convert STC-S to WKT
--------------------------------------------------------------------------------------------------------------------------------
Spatial Reference system definition: WGS 84 is default (SRID=4326)
GEOGCS["<name>", <datum>, <prime meridian>, <angular unit> {,<twin axes>} {,<authority>}]
DATUM["<name>", <spheroid> {,<to wgs84>} {,<authority>}]
SPHEROID["<name>", <semi-major axis>, <inverse flattening> {,<authority>}]
PRIMEM["<name>", <longitude> {,<authority>}]
UNIT["<name>", <conversion factor> {,<authority>}]
AUTHORITY["<name>", "<code>"]
GEOGCS["WGS 84", DATUM["World Geodetic System 1984", ELLIPSOID["WGS 84", 6378137, 298.257223563]], PRIMEM["Greenwich", 0], UNIT["Degree", 0.0174532925199433]]
GEOGCS["ICRS", DATUM["International Celestial Reference System", ELLIPSOID["ICRS", 1, 1000000.0]], PRIMEM["Greenwich", 0], UNIT["Degree", 0.0174532925199433]]

(WGS 84 semi-major axis 6378137.0m ; semi-minor axis 6356752.314140m ; inverse flattening 298.257223563)

New in SQL2012 - SRID 104001 = unit sphere
*/
---------------------------------------------------------------------------------------------------------------------------------
/*
BEGIN TRY DROP FUNCTION ComputeScaling END TRY BEGIN CATCH END CATCH
GO
CREATE function [dbo].[ComputeScaling] (@ra float, @dec float, @unit char)
-- function to convert meters/degree at geodetic latitude
returns float
as begin
	declare @a float=6378137.000000000000		-- Semi-major axis of Earth [WGS 84]
	declare @b float=6356752.314140000000		-- Semi-minor axis of Earth
	declare @e float = 0.081819190842600		-- eccentricity

	declare @l float							-- geodetic latitude
	declare @re float							-- radius of earth at latitude
	declare @rm float							-- radius of curvature in meridian
	declare @rn float							-- radius of curvature in latitude
	declare @arc float							-- arc length in meters
	declare @angle float=radians(1.0)			-- arc subtended in radians (default 1deg)
	
	if (@unit = 'D') SET @angle=radians(1.0)
	if (@unit = 'M') SET @angle=radians(1.0)/60.0
	if (@unit = 'S') SET @angle=radians(1.0)/3600.0
	SET @l=@dec
	
	-- Compute radius of earth at specified latitude (declination)
	-- SET @re=sqrt(( power((power(@a,2)*cos(radians(@l))),2) +
	--			  power((power(@b,2)*sin(radians(@l))),2) )
	--	        /
	--			( power(@a*cos(radians(@l)),2) +
	--			  power(@b*sin(radians(@l)),2) ))
	--			  
	-- Compute radius of curvature along meridian
	SET @rm=@a*(1-power(@e,2))/power(((1-power(@e,2)*power(sin(radians(@l)),2))),1.5)
	
	-- Compute radius of curvature along parallel of latitude
	--SET @rn=@a/power((1-power(@e,2)*power(sin(radians(@l)),2)),0.5)
	
	-- Compute length of arc at this latitude
	SET @arc = @rm * @angle	
	RETURN @arc
end
go
--test
select dbo.Computescaling(0,0,'D')
select dbo.Computescaling(0,90,'D')
select dbo.Computescaling(0,0,'M')
select dbo.Computescaling(0,0,'S')
select dbo.Computescaling(0,-52,'S')
-------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------
BEGIN TRY DROP FUNCTION vDistance END TRY BEGIN CATCH END CATCH
GO
CREATE FUNCTION vDistance(@lng1 float, @lat1 float, @lng2 float, @lat2 float, @metric varchar(2)) 
-- Vincenty function to compute distance between 2 points on oblate spheroid (used for testing but not in final functions)
RETURNS float
AS
BEGIN
DECLARE @gcdx float
DECLARE @lng_rad1 float, @lat_rad1 float, @lng_rad2 float, @lat_rad2 float
DECLARE @wgs84_major float, @wgs84_minor float, @wgs84_flattening float
DECLARE @delta_lng float, @reduced_lat1 float, @reduced_lat2 float, @sin_reduced1 float, @cos_reduced1 float, @sin_reduced2 float, @cos_reduced2 float
DECLARE @lambda_lng float, @lambda_prime float
DECLARE @sin_lambda_lng float, @cos_lambda_lng float, @sin_sigma float, @cos_sigma float
DECLARE @sin_alpha float, @cos_sq_alpha float, @cos2_sigma_m float
DECLARE @C float, @u_sq float, @A float, @B float
DECLARE @sigma float, @delta_sigma float, @iter_limit INT

SET @lng_rad1 = RADIANS(@lng1)
SET @lat_rad1 = RADIANS(@lat1)
SET @lng_rad2 = RADIANS(@lng2)
SET @lat_rad2 = RADIANS(@lat2)

SET @wgs84_major = 6378.137
SET @wgs84_minor = 6356.7523142
SET @wgs84_flattening = 1 / 298.257223563

SET @delta_lng = @lng_rad2 - @lng_rad1

SET @reduced_lat1 = atan((1 - @wgs84_flattening) * tan(@lat_rad1))
SET @reduced_lat2 = atan((1 - @wgs84_flattening) * tan(@lat_rad2))

SET @sin_reduced1 = sin(@reduced_lat1)
SET @cos_reduced1 = cos(@reduced_lat1)
SET @sin_reduced2 = sin(@reduced_lat2)
SET @cos_reduced2 = cos(@reduced_lat2)

SET @lambda_lng = @delta_lng
SET @lambda_prime = 2 * pi()

SET @iter_limit = 20
WHILE abs(@lambda_lng - @lambda_prime) > power(10, -11) and @iter_limit > 0
BEGIN
     SET @sin_lambda_lng = sin(@lambda_lng)
     SET @cos_lambda_lng = cos(@lambda_lng)
     SET @sin_sigma = sqrt(power((@cos_reduced2 * @sin_lambda_lng), 2) +
                      power((@cos_reduced1 * @sin_reduced2 - @sin_reduced1 *
                       @cos_reduced2 * @cos_lambda_lng), 2))
     IF @sin_sigma = 0 RETURN 0

     SET @cos_sigma = (@sin_reduced1 * @sin_reduced2 +
                       @cos_reduced1 * @cos_reduced2 * @cos_lambda_lng)
     SET @sigma = atn2(@sin_sigma, @cos_sigma)
     SET @sin_alpha = @cos_reduced1 * @cos_reduced2 * @sin_lambda_lng / @sin_sigma
     SET @cos_sq_alpha = 1 - power(@sin_alpha, 2)
     IF @cos_sq_alpha = 0 SET @cos2_sigma_m = @cos_sigma - 2 * (@sin_reduced1 * @sin_reduced2 / @cos_sq_alpha)
     ELSE SET @cos2_sigma_m = 0.0
     
     SET @C = @wgs84_flattening / 16.0 * @cos_sq_alpha * (4 + @wgs84_flattening * (4 - 3 * @cos_sq_alpha))
     SET @lambda_prime = @lambda_lng
     SET @lambda_lng = (@delta_lng + (1 - @C) * @wgs84_flattening * @sin_alpha *
                   (@sigma + @C * @sin_sigma *
                    (@cos2_sigma_m + @C * @cos_sigma *
                     (-1 + 2 * power(@cos2_sigma_m, 2)))))
     SET @iter_limit = @iter_limit - 1
END
IF @iter_limit = 0 RETURN NULL

SET @u_sq = @cos_sq_alpha * (power(@wgs84_major, 2) - power(@wgs84_minor, 2)) / power(@wgs84_minor, 2)
SET @A = 1 + @u_sq / 16384.0 * (4096 + @u_sq * (-768 + @u_sq * (320 - 175 * @u_sq)))
SET @B = @u_sq / 1024.0 * (256 + @u_sq * (-128 + @u_sq * (74 - 47 * @u_sq)))
SET @delta_sigma = (@B * @sin_sigma * (@cos2_sigma_m + @B / 4. * (@cos_sigma * (-1 + 2 * power(@cos2_sigma_m, 2)) -
                    @B / 6. * @cos2_sigma_m * (-3 + 4 * power(@sin_sigma, 2)) * (-3 + 4 * power(@cos2_sigma_m, 2)))))

SET @gcdx = @wgs84_minor * @A * (@sigma - @delta_sigma)
IF @metric = 'km' RETURN @gcdx
ELSE IF @metric = 'mi' RETURN @gcdx * 0.621371192
ELSE IF @metric = 'nm' RETURN @gcdx / 1.852
RETURN @gcdx;
END
go
*/
-------------------------------------------------------------------------------------------------------------------------
BEGIN TRY DROP FUNCTION fSearchBox END TRY BEGIN CATCH END CATCH
GO
CREATE FUNCTION fSearchBox(@minra nvarchar(max), @mindec nvarchar(max), @maxra nvarchar(max),  @maxdec nvarchar(max))
		-- Corners of box are in degrees
		-- Requires view ObjectList containing objID,RA,DEC,Spatial		
RETURNS @neighbours TABLE (objID bigint)
AS BEGIN
	-- Declare variables
	DECLARE @boxsearch geography
	DECLARE @wkt nvarchar(max)
	-- Create box for search
	SET @wkt='POLYGON(('+STR(@minra,12,8)+' '+STR(@mindec,12,8)+','+
						 STR(@maxra,12,8)+' '+STR(@mindec,12,8)+','+
						 STR(@maxra,12,8)+' '+STR(@maxdec,12,8)+','+
						 STR(@minra,12,8)+' '+STR(@maxdec,12,8)+','+
						 STR(@minra,12,8)+' '+STR(@mindec,12,8)+'))'

	-- Check SQLserver for which Spatial Reference Identifier (SRID) to use
/*	declare @srid int
	set @srid=(select top 1 Spatial.STSrid from ObjectList where spatial is not null)

	IF @srid=4326	SET @boxsearch=geography::STGeomFromText(@wkt,4326)
	IF @srid=104001 SET @boxsearch=geography::STGeomFromText(@wkt,104001)
*/
	
	SET @boxsearch=geography::STGeomFromText(@wkt,104001)	-- Create table of objects intersecting box
	INSERT @neighbours SELECT objID FROM ObjectList WHERE Spatial.STIntersects(@boxsearch)=1 
	RETURN 
END
GO
--select * from publicVOview as P, fSearchBox(10,40,11,41) as N where P.objid=N.objID
--select top 10 spatial.STSrid from objectlist
---------------------------------------------------------------------------------------------------------------------------------
BEGIN TRY DROP FUNCTION fSearchCircle END TRY BEGIN CATCH END CATCH
GO
CREATE FUNCTION fSearchCircle(@ra float,@dec float,@r float)
		-- RA and DEC are in degrees, Radius is in degrees
		-- Requires view ObjectList containing objID,RA,DEC,Spatial
RETURNS @neighbours TABLE (objID bigint)
AS BEGIN
	-- Declare variables
	DECLARE @location geography
	DECLARE @conesearch geography
	DECLARE @radius float
	DECLARE @wkt nvarchar(max)
	DECLARE @meters_per_arcsecond float
	DECLARE @meters_per_arcminute float
	DECLARE @meters_per_degree float

		-- Check SQLserver for which Spatial Reference Identifier (SRID) to use
/*	declare @srid int
	set @srid=(select top 1 Spatial.STSrid from ObjectList where spatial is not null)

	IF @srid=4326	
	BEGIN
		-- Set location of search
		SET @wkt='POINT('+STR(@ra,12,8)+' '+STR(@dec,12,8)+')'
		SET @location=geography::STGeomFromText(@wkt,4326)

		-- Create circle of specified radius
		SET @meters_per_degree = dbo.ComputeScaling(@ra,@dec,'D')
		SET @radius=@r*@meters_per_degree
		SET @conesearch=@location.STBuffer(@radius)
	END
	IF @srid=104001 
*/
--	BEGIN
		-- Set location of search
		SET @wkt='POINT('+STR(@ra,12,8)+' '+STR(@dec,12,8)+')'
		SET @location=geography::STGeomFromText(@wkt,104001)

		-- Create circle of specified radius
		SET @radius=RADIANS(@r)
		SET @conesearch=@location.STBuffer(@radius)
--	END

	-- Create table of objects intersecting circle
	INSERT @neighbours 
		SELECT objID FROM ObjectList WHERE Spatial.STIntersects(@conesearch)=1 
	RETURN
END
GO
--select * FROM catalogrecord as P,fSearchCircle(5.5125,40.085,0.1) as N where P.objID=N.objID 
---------------------------------------------------------------------------------------------------------------------------------
BEGIN TRY DROP FUNCTION fSearchPoint END TRY BEGIN CATCH END CATCH
GO
CREATE FUNCTION fSearchPoint(@ra float,@dec float)
		-- RA and DEC are in degrees
		-- Requires view ObjectList containing objID,RA,DEC,Spatial
		-- Looks for point contained within a spatial shape
RETURNS @neighbours TABLE (objID bigint)
AS BEGIN
	-- Declare variables
	DECLARE @location geography
	DECLARE @wkt nvarchar(max)

	-- Check SQLserver for which Spatial Reference Identifier (SRID) to use
	/*
	declare @srid int
	set @srid=(select top 1 Spatial.STSrid from ObjectList where spatial is not null)

	IF @srid=4326	
	BEGIN
		-- Set location of search
		SET @wkt='POINT('+STR(@ra,12,8)+' '+STR(@dec,12,8)+')'
		SET @location=geography::STGeomFromText(@wkt,4326)
	END
	IF @srid=104001 
	*/
	--BEGIN
		-- Set location of search
		SET @wkt='POINT('+STR(@ra,12,8)+' '+STR(@dec,12,8)+')'
		SET @location=geography::STGeomFromText(@wkt,104001)
	--END

	-- Create table of objects intersecting circle
	INSERT @neighbours 
		SELECT objID FROM ObjectList WHERE Spatial.STIntersects(@location)=1 
	RETURN
END
GO
--select * from plane p, fSearchPoint(5.5125,40.085) as N where p.planeID=N.objID
---------------------------------------------------------------------------------------------------------------------------------
BEGIN TRY DROP FUNCTION fSearchCircleDistance END TRY BEGIN CATCH END CATCH
GO
CREATE FUNCTION fSearchCircleDistance(@ra float,@dec float,@r float)
		-- RA and DEC are in degrees, Radius is in degrees
		-- Requires view ObjectList containing objID,RA,DEC,Spatial
RETURNS @neighbours TABLE (objID bigint, distance float)
AS BEGIN
	-- Declare variables
	DECLARE @location geography
	DECLARE @conesearch geography
	DECLARE @radius float
	DECLARE @wkt nvarchar(max)
	DECLARE @meters_per_arcsecond float
	DECLARE @meters_per_arcminute float
	DECLARE @meters_per_degree float

		-- Check SQLserver for which Spatial Reference Identifier (SRID) to use
/*
	declare @srid int
	set @srid=(select top 1 Spatial.STSrid from ObjectList where spatial is not null)

	IF @srid=4326	
	BEGIN
		-- Set location of search
		SET @wkt='POINT('+STR(@ra,12,8)+' '+STR(@dec,12,8)+')'
		SET @location=geography::STGeomFromText(@wkt,4326)

		-- Create circle of specified radius
		SET @meters_per_degree = dbo.ComputeScaling(@ra,@dec,'D')
		SET @meters_per_arcsecond = @meters_per_degree/3600.0
		SET @radius=@r*@meters_per_degree
		SET @conesearch=@location.STBuffer(@radius)
	
	-- Create table of objects intersecting circle and distance in arcsec
		INSERT @neighbours 
			SELECT objID,@location.STDistance(Spatial)/@meters_per_arcsecond AS distance
			FROM ObjectList WHERE Spatial.STIntersects(@conesearch)=1 

	END
	IF @srid=104001 
*/
	--BEGIN
		-- Set location of search
		SET @wkt='POINT('+STR(@ra,12,8)+' '+STR(@dec,12,8)+')'
		SET @location=geography::STGeomFromText(@wkt,104001)

		-- Create circle of specified radius
		SET @radius=RADIANS(@r)
		SET @conesearch=@location.STBuffer(@radius)
	
		-- Create table of objects intersecting circle and distance in arcsec
		INSERT @neighbours 
			SELECT objID,degrees(@location.STDistance(Spatial))*3600.0 AS distance
			FROM ObjectList WHERE Spatial.STIntersects(@conesearch)=1 
	--END

	RETURN
END
GO
/*
select * FROM publicVOview_AllWise as P,fSearchCircle(5.5125,40.085,0.1) as N where P.objID=N.objID
select * FROM publicVOview_AllWise as P,fSearchCircleDistance(5.5125,40.085,0.1) as N where P.objID=N.objID order by distance
*/
/*******************************************************************************************************************************/
--update imageObservations set spatial=geography::STGeomFromText('POINT('+STR(ra,12,8)+' '+STR(dec,12,8)+')',104001)