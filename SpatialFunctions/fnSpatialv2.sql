select 'Installing v2 Spatial functions'
-- ***********************************************************************************************
/*
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[objectCoords]') AND type in (N'U'))
DROP TABLE [dbo].objectCoords
go
CREATE TABLE objectCoords(
	objID bigint not null CONSTRAINT objectCoords_PK_objID PRIMARY KEY CLUSTERED (objID ASC),
	ra float null,
	dec float null,
	spatial geography null,
	cx float null,
	cy float null,
	cz float null,
	htmID bigint null,
	healpixID bigint null,
	glon float null,
	glat float null,
	elon float null,
	elat float null,
	zoneID bigint null)
GO

-- Edit this depending on catalog
INSERT INTO objectCoords(objID,ra,dec) Select objID,rightascension,declination from gsc1Record
GO
-- Add spatial, HTM & healpix
update objectCoords 
	set Spatial=geography::Point(STR(dec,12,8),STR(ra,12,8),104001), 
		cx=COS(RADIANS(dec))*COS(RADIANS(ra)),
		cy=COS(RADIANS(dec))*SIN(RADIANS(ra)),
		cz=SIN(RADIANS(dec)),
		htmID=dbo.fHtmEq(ra,dec),
		glon=(select glon from fnCoordSys_EquatorialToGalactic(ra,dec)),
		glat=(select glat from fnCoordSys_EquatorialToGalactic(ra,dec)),
		elon=(select elon from fnCoordSys_EquatorialToEcliptic(ra,dec)),
		elat=(select elat from fnCoordSys_EquatorialToEcliptic(ra,dec)),
		zoneID=cast(floor((90+dec)/0.0044444) as bigint)
	--where ra is not null
GO
update objectCoords 
	set 
		cx=COS(RADIANS(dec))*COS(RADIANS(ra)),
		cy=COS(RADIANS(dec))*SIN(RADIANS(ra)),
		cz=SIN(RADIANS(dec)),
		glon=(select glon from fnCoordSys_EquatorialToGalactic(ra,dec)),
		glat=(select glat from fnCoordSys_EquatorialToGalactic(ra,dec)),
		elon=(select elon from fnCoordSys_EquatorialToEcliptic(ra,dec)),
		elat=(select elat from fnCoordSys_EquatorialToEcliptic(ra,dec)),
		zoneID=cast(floor((90+dec)/0.0044444) as bigint)

update objectCoords 
	set 
		cx=COS(RADIANS(dec))*COS(RADIANS(ra)),
		cy=COS(RADIANS(dec))*SIN(RADIANS(ra)),
		cz=SIN(RADIANS(dec)),
		zoneID=cast(floor((90+dec)/0.0044444) as bigint)
update ObjectCoords
	set glon=F.glon, glat=F.glat
	from ObjectCoords C
	cross apply dbo.fnCoordSys_EquatorialToGalactic(C.ra,C.dec) F
update ObjectCoords
	set elon=F.elon, elat=F.elat
	from ObjectCoords C
	cross apply dbo.fnCoordSys_EquatorialToEcliptic(C.ra,C.dec) F
go

CREATE SPATIAL INDEX objectCoords_idx_spatial ON objectCoords(Spatial) USING GEOGRAPHY_AUTO_GRID 
GO
CREATE NONCLUSTERED INDEX [objectCoords_idx_htmID] ON [dbo].[objectCoords]([htmID] ASC) INCLUDE ([objID],[cx],[cy],[cz]) 
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, DATA_COMPRESSION = PAGE) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX objectCoords_idx_healpixID ON objectCoords (healpixID ASC)
GO
CREATE NONCLUSTERED INDEX objectCoords_idx_glon ON objectCoords (glon ASC)
GO
CREATE NONCLUSTERED INDEX objectCoords_idx_glat ON objectCoords (glat ASC)
GO
CREATE NONCLUSTERED INDEX objectCoords_idx_elon ON objectCoords (elon ASC)
GO
CREATE NONCLUSTERED INDEX objectCoords_idx_elat ON objectCoords (elat ASC)
GO
CREATE NONCLUSTERED INDEX objectCoords_idx_zoneID ON objectCoords (zoneID ASC)
GO

update ScienceCommon set s_region_encoded=dbo.fnStc_convertSTCStoSpatial(s_region,104001)
  select * FROM ScienceCommon as P,fnSpatial_SearchCircle(333.960395,-14.573791,0.1) as N where P.ArchiveFileID=N.objID 
  select * FROM NirspecScience P,fnSpatial_SearchCircle(333.960395,-14.573791,0.1) as N where P.ArchiveFileID=N.objID 
  select * FROM NirspecScienceAll P,fnSpatial_SearchCircle(333.960395,-14.573791,0.1) as N where P.ArchiveFileID=N.objID 
*/
/*******************************************************************************************************************************
Routines to install Spatial functions in SQLserver database

Requirements :
The main table must contain objID, RA, DEC columns and called CatalogRecord (or you edit SP below)
The objID column should be unique & primary key
A table called objectCoords should be created containing objID, RA, DEC, Spatial (used by search functions)
The spatial column should be indexed (SP included)

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
--select top 10 spatial.STSrid from objectCoords /objectCoords
---------------------------------------------------------------------------------------------------------------------------------
BEGIN TRY DROP FUNCTION fnSpatial_SearchCircle END TRY BEGIN CATCH END CATCH
GO
CREATE FUNCTION fnSpatial_SearchCircle(@ra float,@dec float,@r float)
		-- RA and DEC are in degrees, Radius is in degrees
		-- Requires view objectCoords containing objID,RA,DEC,Spatial
RETURNS @neighbours TABLE (objID bigint)
AS BEGIN
	-- Declare variables
	DECLARE @location geography
	DECLARE @conesearch geography

	-- Set location of search
	SET @location=geography::STGeomFromText('POINT('+STR(@ra,12,8)+' '+STR(@dec,12,8)+')',104001)

	-- Create circle of specified radius
	SET @conesearch=@location.STBuffer(RADIANS(@r))

	-- Create table of objects intersecting circleobjectC
	INSERT @neighbours 
		SELECT objID 
		FROM objectCoords WHERE Spatial.STIntersects(@conesearch)=1 
	RETURN
END
GO
--select * from dbo.fnSpatial_SearchCircle(5.5125,40.085,0.1) 
--select * FROM apassPublicVoView as P,fnSpatial_SearchCircle(5.5125,40.085,0.1) as N where P.objID=N.objID 
---------------------------------------------------------------------------------------------------------------------------------
BEGIN TRY DROP FUNCTION fnSpatial_SearchCircleDistance END TRY BEGIN CATCH END CATCH
GO
CREATE FUNCTION fnSpatial_SearchCircleDistance(@ra float,@dec float,@r float)
		-- RA and DEC are in degrees, Radius is in degrees
		-- Requires view objectCoords containing objID,RA,DEC,Spatial
RETURNS @neighbours TABLE (objID bigint, distance float)
AS BEGIN
	-- Declare variables
	DECLARE @location geography
	DECLARE @conesearch geography

	-- Set location of search
	SET @location=geography::STGeomFromText('POINT('+STR(@ra,12,8)+' '+STR(@dec,12,8)+')',104001)

	-- Create circle of specified radius
	SET @conesearch=@location.STBuffer(RADIANS(@r))
	
	-- Create table of objects intersecting circle and distance in arcsec
	INSERT @neighbours 
		SELECT objID,degrees(@location.STDistance(Spatial))*3600.0 AS distance
		FROM objectCoords WHERE Spatial.STIntersects(@conesearch)=1 
	RETURN
END
GO
--select * FROM igslPublicVOview as P,fnSpatial_SearchCircleDistance(5.5125,40.085,0.1) as N where P.objID=N.objID 
---------------------------------------------------------------------------------------------------------------------------------
BEGIN TRY DROP FUNCTION fnSpatial_SearchPoint END TRY BEGIN CATCH END CATCH
GO
CREATE FUNCTION fnSpatial_SearchPoint(@ra float,@dec float)
		-- RA and DEC are in degrees
		-- Requires view objectCoords containing objID,RA,DEC,Spatial
		-- Looks for point contained within a spatial shape
RETURNS @neighbours TABLE (objID bigint)
AS BEGIN
	-- Declare variables
	DECLARE @location geography

	-- Set location of search
	SET @location=geography::STGeomFromText('POINT('+STR(@ra,12,8)+' '+STR(@dec,12,8)+')',104001)

	-- Create table of objects intersecting circle
	INSERT @neighbours 
		SELECT objID 
		FROM objectCoords WHERE Spatial.STIntersects(@location)=1 
	RETURN
END
GO
--select * from catalogrecord p, fnSpatial_SearchPoint(5.5125,40.085) as N where p.objID=N.objID
-------------------------------------------------------------------------------------------------------------------------
BEGIN TRY DROP FUNCTION fnSpatial_SearchBox END TRY BEGIN CATCH END CATCH
GO
CREATE FUNCTION fnSpatial_SearchBox(@minra nvarchar(max), @mindec nvarchar(max), @maxra nvarchar(max),  @maxdec nvarchar(max))
		-- Corners of box are in degrees
		-- Requires view objectCoords containing objID,RA,DEC,Spatial		
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
	
	SET @boxsearch=geography::STGeomFromText(@wkt,104001)	-- Create table of objects intersecting box
	INSERT @neighbours SELECT objID FROM objectCoords WHERE Spatial.STIntersects(@boxsearch)=1 
	RETURN 
END
GO
--select * from catalogrecord as P, fnSpatial_SearchBox(10,40,11,41) as N where P.objid=N.objID
--select top 10 spatial.STSrid from objectCoords
-------------------------------------------------------------------------------------------------------------------------
BEGIN TRY DROP FUNCTION fnSpatial_SearchSTCSFootprint END TRY BEGIN CATCH END CATCH
GO
CREATE FUNCTION fnSpatial_SearchSTCSFootprint(@stcs nvarchar(max))
RETURNS @neighbours TABLE (objID bigint)
AS BEGIN
	-- Declare variables
	DECLARE @footprintSearch geography
	-- Create spatial footprint for search
	SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
	-- Create table of objects intersecting box
	INSERT @neighbours SELECT objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
	RETURN 
END
GO
--select * from publicVOview as P, dbo.fnSpatial_SearchSTCSFootprint(mast.dbo.fnMission_computeWFIRSTFootprint('WFI','WFI',0,0,0,'')) as N where P.objid=N.objID
BEGIN TRY DROP FUNCTION fnObsCore_SearchSTCSFootprint END TRY BEGIN CATCH END CATCH
GO
CREATE FUNCTION fnObsCore_SearchSTCSFootprint(@stcs nvarchar(max))
RETURNS @obsCore TABLE 
		(dataproduct_type varchar(32),calib_level int,obs_collection varchar(256),
		 obs_id varchar(256),obs_publisher_did varchar(1024),
		 access_url varchar(max), access_format varchar(32), access_estsize bigint,
		 target_name varchar(256),s_ra float,s_dec float, s_fov int,
		 s_region varchar(max),s_xel1 int, s_xel2 int,s_resolution float,
         t_min float, t_max float, t_exptime float, t_resolution float, t_xel int, 
		 em_min float, em_max float, em_res_power float, em_xel int, 
		 o_ucd int, pol_states varchar(2), pol_xel int, 
         facility_name varchar(256), instrument_name varchar(32), objID bigint)
AS BEGIN
	-- Declare variables
	DECLARE @footprintSearch geography
	DECLARE @neighbours table(objID bigint)
	-- Create spatial footprint for search
	SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
	-- Create table of objects intersecting box
	INSERT @neighbours SELECT objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
	insert @obsCore select 
			O.dataproduct_type,O.calib_level,O.obs_collection,
			O.obs_id,O.obs_publisher_did,
			O.access_url, O.access_format, O.access_estsize,
			O.target_name,O.s_ra ,O.s_dec , O.s_fov,
			O.s_region,O.s_xel1, O.s_xel2,O.s_resolution,
			O.t_min, O.t_max, O.t_exptime, O.t_resolution, O.t_xel , 
			O.em_min, O.em_max, O.em_res_power , O.em_xel , 
			O.o_ucd, O.pol_states , O.pol_xel , 
			O.facility_name , O.instrument_name , O.objID 
	from @neighbours N join obsCore11 O on O.objID=N.objID 
	--select * from ObsPointing as P, dbo.fnSpatial_SearchSTCSFootprint('circle 5.6 13.5 1') as N where P.objid=N.objID
	RETURN 
END
GO

-------------------------------------------------------------------------------------------------------------------------
BEGIN TRY DROP FUNCTION fnSpatial_SearchTelescopeFootprint END TRY BEGIN CATCH END CATCH
GO
CREATE FUNCTION fnSpatial_SearchTelescopeFootprint(@telescope varchar(32), @instrument varchar(32), @aperture varchar(32), @v1RA float, @v1Dec float, @v3PosAng float)
RETURNS @neighbours TABLE (telescope varchar(32), instrument varchar(32), aperture varchar(32), v1RA float, v1Dec float, v3PosAng float, objID bigint)
AS BEGIN
	declare @stcs varchar(max)= null
	if @telescope='HST' set @stcs=mast.dbo.fnMission_computeHSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
	if @telescope='JWST' set @stcs=mast.dbo.fnMission_computeJWSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
	if @telescope='WFIRST' set @stcs=mast.dbo.fnMission_computeWFIRSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
	-- Declare variables
	DECLARE @footprintSearch geography

	if @stcs is not null
	begin
		-- Create spatial footprint for search
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		-- Create table of objects intersecting box
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
	end
	RETURN 
END
GO
--select * from catalogrecord as P, dbo.fnSpatial_SearchTelescopeFootprint('WFIRST','WFI','WFI',0,0,0) as N where P.objid=N.objID
--select * from GSC23publicVOview as P, dbo.fnSpatial_SearchTelescopeFootprint('jwst','fgs','fgs1',0,0,0) as N where P.objid=N.objID
-------------------------------------------------------------------------------------------------------------------------
-- The apertures in this function must match fnMission_computeHSTfootprint
BEGIN TRY DROP FUNCTION fnSpatial_HSTFootprint END TRY BEGIN CATCH END CATCH
GO
CREATE FUNCTION fnSpatial_HSTFootprint(@instrument varchar(32), @aperture varchar(32), @v1RA float, @v1Dec float, @v3PosAng float)
	-- special function for doing catalog statistics for WFIRST GS study 
RETURNS @neighbours TABLE (telescope varchar(32), instrument varchar(32), aperture varchar(32), v1RA float, v1Dec float, v3PosAng float, objID bigint)
AS BEGIN
	-- Declare variables
	declare @telescope varchar(32) ='HST'
	declare @stcs varchar(max), @footprintSearch geography
	declare @counter int=0, @count varchar(2)

	if (@instrument='ACS' and @aperture='ACS')
	begin
		set @aperture='JWFC1'
		set @stcs=mast.dbo.fnMission_computeHSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
		set @aperture='JWFC2'
		set @stcs=mast.dbo.fnMission_computeHSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
		set @aperture='JHRC'
		set @stcs=mast.dbo.fnMission_computeHSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
		set @aperture='JSBC'
		set @stcs=mast.dbo.fnMission_computeHSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
	end
	if (@instrument='ACS' and @aperture='WFC')
	begin
		set @aperture='JWFC1'
		set @stcs=mast.dbo.fnMission_computeHSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
		set @aperture='JWFC2'
		set @stcs=mast.dbo.fnMission_computeHSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
	end
	if (@instrument='FGS' and @aperture='FGS')
	begin
		set @aperture='FGS1'
		set @stcs=mast.dbo.fnMission_computeHSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
		set @aperture='FGS2'
		set @stcs=mast.dbo.fnMission_computeHSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
		set @aperture='FGS3'
		set @stcs=mast.dbo.fnMission_computeHSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
	end
	if (@instrument='NICMOS' and @aperture='NICMOS')
	begin
		set @aperture='NIC1'
		set @stcs=mast.dbo.fnMission_computeHSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
		set @aperture='NIC2'
		set @stcs=mast.dbo.fnMission_computeHSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
		set @aperture='NIC3'
		set @stcs=mast.dbo.fnMission_computeHSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
	end
	if (@instrument='WFC3' and @aperture='WFC3')
	begin
		set @aperture='IUVIS1'
		set @stcs=mast.dbo.fnMission_computeHSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
		set @aperture='IUVIS2'
		set @stcs=mast.dbo.fnMission_computeHSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
		set @aperture='IIR'
		set @stcs=mast.dbo.fnMission_computeHSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
	end
	if (@instrument='WFC3' and @aperture='IR')
	begin
		set @aperture='IIR'
		set @stcs=mast.dbo.fnMission_computeHSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
	end
	if (@instrument='WFC3' and @aperture='UVIS')
	begin
		set @aperture='IUVIS1'
		set @stcs=mast.dbo.fnMission_computeHSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
		set @aperture='IUVIS2'
		set @stcs=mast.dbo.fnMission_computeHSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
	end
	if (@instrument='WFPC' and @aperture='WFPC')
	begin
		set @aperture='WWF1'
		set @stcs=mast.dbo.fnMission_computeHSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
		set @aperture='WWF2'
		set @stcs=mast.dbo.fnMission_computeHSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
		set @aperture='WWF3'
		set @stcs=mast.dbo.fnMission_computeHSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
		set @aperture='WWF4'
		set @stcs=mast.dbo.fnMission_computeHSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
	end
	if (@instrument='WFPC2' and @aperture='WFPC2')
	begin
		set @aperture='UPC1'
		set @stcs=mast.dbo.fnMission_computeHSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
		set @aperture='UWF2'
		set @stcs=mast.dbo.fnMission_computeHSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
		set @aperture='UWF3'
		set @stcs=mast.dbo.fnMission_computeHSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
		set @aperture='UWF4'
		set @stcs=mast.dbo.fnMission_computeHSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
	end

	-- catch all other apertures
	else 
	begin
		set @stcs=mast.dbo.fnMission_computeHSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
	end
	RETURN 
END
GO
--select * from catalogrecord as P, dbo.fnSpatial_HSTFootprint('acs','acs',0,0,0) as N where P.objid=N.objID
-------------------------------------------------------------------------------------------------------------------------
-- The apertures in this function must match fnMission_computeJWSTfootprint
BEGIN TRY DROP FUNCTION fnSpatial_JWSTFootprint END TRY BEGIN CATCH END CATCH
GO
CREATE FUNCTION fnSpatial_JWSTFootprint(@instrument varchar(32), @aperture varchar(32), @v1RA float, @v1Dec float, @v3PosAng float)
	-- special function for doing catalog statistics for WFIRST GS study 
RETURNS @neighbours TABLE (telescope varchar(32), instrument varchar(32), aperture varchar(32), v1RA float, v1Dec float, v3PosAng float, objID bigint)
AS BEGIN
	-- Declare variables
	declare @telescope varchar(32) ='JWST'
	declare @stcs varchar(max), @footprintSearch geography
	declare @counter int=0, @count varchar(2)

	if (@instrument='FGS' and @aperture='FGS')
	begin
		set @aperture='FGS1'
		set @stcs=mast.dbo.fnMission_computeJWSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
		set @aperture='FGS2'
		set @stcs=mast.dbo.fnMission_computeJWSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
	end
	if (@instrument='MIRI' and @aperture='MIRI')
	begin
		set @aperture='MIRIMAGE'
		set @stcs=mast.dbo.fnMission_computeJWSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
		set @aperture='MIRIFULONG'
		set @stcs=mast.dbo.fnMission_computeJWSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
		set @aperture='MIRIFUSHORT'
		set @stcs=mast.dbo.fnMission_computeJWSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
		set @aperture='MIRIPRISM'
		set @stcs=mast.dbo.fnMission_computeJWSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
	end
	if (@instrument='NIRCAM' and @aperture='NIRCAM')
	begin
		set @aperture='NRCA1'
		set @stcs=mast.dbo.fnMission_computeJWSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
		set @aperture='NRCA2'
		set @stcs=mast.dbo.fnMission_computeJWSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
		set @aperture='NRCA3'
		set @stcs=mast.dbo.fnMission_computeJWSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
		set @aperture='NRCA4'
		set @stcs=mast.dbo.fnMission_computeJWSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
		set @aperture='NRCB1'
		set @stcs=mast.dbo.fnMission_computeJWSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
		set @aperture='NRCB2'
		set @stcs=mast.dbo.fnMission_computeJWSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
		set @aperture='NRCB3'
		set @stcs=mast.dbo.fnMission_computeJWSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
		set @aperture='NRCB4'
		set @stcs=mast.dbo.fnMission_computeJWSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
	end
	if (@instrument='NIRCAM' and @aperture='NRCA')
	begin
		set @aperture='NRCA1'
		set @stcs=mast.dbo.fnMission_computeJWSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
		set @aperture='NRCA2'
		set @stcs=mast.dbo.fnMission_computeJWSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
		set @aperture='NRCA3'
		set @stcs=mast.dbo.fnMission_computeJWSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
		set @aperture='NRCA4'
		set @stcs=mast.dbo.fnMission_computeJWSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
	end
	if (@instrument='NIRCAM' and @aperture='NRCB')
	begin
		set @aperture='NRCB1'
		set @stcs=mast.dbo.fnMission_computeJWSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
		set @aperture='NRCB2'
		set @stcs=mast.dbo.fnMission_computeJWSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
		set @aperture='NRCB3'
		set @stcs=mast.dbo.fnMission_computeJWSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
		set @aperture='NRCB4'
		set @stcs=mast.dbo.fnMission_computeJWSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
	end
	if (@instrument='NIRSPEC' and @aperture='NIRSPEC')
	begin
		set @aperture='NRS1'
		set @stcs=mast.dbo.fnMission_computeJWSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
		set @aperture='NRS2'
		set @stcs=mast.dbo.fnMission_computeJWSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
		set @aperture='NRS3'
		set @stcs=mast.dbo.fnMission_computeJWSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
		set @aperture='NRS4'
		set @stcs=mast.dbo.fnMission_computeJWSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
	end
	if (@instrument='NIRSPEC' and @aperture='NRS')
	begin
		set @aperture='NRS1'
		set @stcs=mast.dbo.fnMission_computeJWSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
		set @aperture='NRS2'
		set @stcs=mast.dbo.fnMission_computeJWSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
		set @aperture='NRS3'
		set @stcs=mast.dbo.fnMission_computeJWSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
		set @aperture='NRS4'
		set @stcs=mast.dbo.fnMission_computeJWSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
	end

	-- catch all other apertures
	else 
	begin
		set @stcs=mast.dbo.fnMission_computeJWSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
	end
	RETURN 
END
GO
--select * from twomasspublicvoview as P, dbo.fnSpatial_JWSTFootprint('fgs','fgs',0,0,0) as N where P.objid=N.objID
-------------------------------------------------------------------------------------------------------------------------
-- The apertures in this function must match fnMission_computeWFIRSTfootprint
BEGIN TRY DROP FUNCTION fnSpatial_WFIRSTFootprint END TRY BEGIN CATCH END CATCH
GO
CREATE FUNCTION fnSpatial_WFIRSTFootprint(@instrument varchar(32), @aperture varchar(32), @v1RA float, @v1Dec float, @v3PosAng float)
	-- special function for doing catalog statistics for WFIRST GS study 
RETURNS @neighbours TABLE (telescope varchar(32), instrument varchar(32), aperture varchar(32), v1RA float, v1Dec float, v3PosAng float, objID bigint)
AS BEGIN
	-- Declare variables
	declare @telescope varchar(32) ='WFIRST'
	declare @stcs varchar(max), @footprintSearch geography
	declare @counter int=0, @count varchar(2)

	if @aperture='WFI'
	while @counter<=17
	begin
		set @counter=@counter+1
		set @count=cast(@counter as varchar)
		set @aperture='SCA'+dbo.fnStr_lpad(@count,2,'0')
		set @stcs=mast.dbo.fnMission_computeWFIRSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
	end
	-- catch all other apertures
	else 
	begin
		set @stcs=mast.dbo.fnMission_computeWFIRSTfootprint(@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,'') 
		SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
		INSERT @neighbours SELECT @telescope,@instrument,@aperture,@v1RA,@v1Dec,@v3PosAng,objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
	end
	RETURN 
END
GO
--select * from wisepublicvoview as P, dbo.fnSpatial_WFIRSTFootprint('wfi','wfi',0,0,0) as N where P.objid=N.objID

/*******************************************************************************************************************************/
--select mast.dbo.fnMission_computeHSTfootprint('ACS','ACS',187.63218489,12.321619,0,'') 
--select dbo.fnStc_convertSTCStoSpatial(mast.dbo.fnMission_computeHSTfootprint('ACS','ACS',187.63218489,12.321619,0,''),104001)
--SELECT * FROM wisepublicvoview WHERE Spatial.STIntersects(dbo.fnStc_convertSTCStoSpatial(mast.dbo.fnMission_computeHSTfootprint('ACS','ACS',187.63218489,12.321619,0,''),104001))=1 
--DBCC DBREINDEX('objectCoords',' ',100)
