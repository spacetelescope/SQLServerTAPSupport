# SQLServerTAPSupport
Support functions in SQL for IVOA Table Access Protocol (TAP) services with a Microsoft SQL Server back end. 
Written at Space Telescope Science Institute as part of the NASA Astronomical Virtual Observatories (NAVO) project sponsored by NASA.
The project is available under the GPLv3 license.

This repository contains SQL functions to install in a Microsoft SQL Server database for supporting specialized TAP services.
IVOA Table Access Protocol services are RESTful interfaces to tabular data with a variety of back end support databases. 
At STScI, we support TAP services using Microsoft SQL Server 2012 and IIS8. This project is intended for other developers working with a MSSQL back-end for astronomical data, particularly using IVOA standards like TAP.


The TAP standard is defined here: http://www.ivoa.net/documents/TAP/
TAP services use the Astronomical Data Query Language (ADQL), which is a superset of SQL92, documented at http://www.ivoa.net/documents/latest/ADQL.html

Built on top of the generic TAP architecture are standards for other services with specified schemas for astronomical data and service metadata.
These specific schemas also require additional query functionality beyond the ADQL standard, and which are not built into Microsoft SQL Server. These functions are provided here.

For the Registry Table Access Protocol (RegTAP) standard, string search and concatenation functions are required.
http://www.ivoa.net/documents/RegTAP/ defines the RegTAP protocol, database schema, and these required functions.
Our implementation of these functions is in the directory "RegTAPFunctions". It is based on the GPLv3 package GroupConcat with source available at https://groupconcat.codeplex.com.

For the Observation Core Data Model Table Access Protocol (ObsTAP, using the ObsCore schema) standard, geometric and spatial query functions are required.
The ObsTAP standard is an IVOA standard with several implementations across data centers worldwide. 
The current version of the ObsTAP standard is available through: http://ivoa.net/documents/ObsCore/index.html
This project provides the necessary underlying functionality for geometric TAP queries on ObsCore data. 
In particular, the stored procedure fnObsCore_SearchSTCSFootprint(@stcs nvarchar(max)) 
is used by the STScI TAP service and an STScI-based branch of the taplib adql parser (https://github.com/gmantele/taplib, https://github.com/theresadower/taplib STScI branch) to do geometric queries using CONTAINS and POINT, CIRCLE, BOX, and POLYGON.

Further, the STScI TAP service for observational holdings, which supports ObsCore geometric queries, also provides a superset of the 
metadata fed into the Obscore data model. This metadata is also in an international standard, which is not yet an IVOA recommendation,
the Common Archive Observation Model, version 2. A basic overview is available via the Canadian Astronomy Data Centre(http://www.cadc-ccda.hia-iha.nrc-cnrc.gc.ca/caom2/).
Searching CAOM metadata geometrically involves the CaomPlane table; a spatial search function is provided for querying this in the same manner as ObsCore.


The spatial query functions provided will require Microsoft SQL Server version 2012 or newer, with geometric support available.
Further database requirements, for functionality and query optimisation include: (as listed from InstallSpatial.sql)
 * The table to add geometric support for must contain objID, RA, DEC and Spatial columns. By default it is called CatalogRecord; this can be edited.
 * The objID column should be unique & primary key
 * The spatial column should be indexed (SP included)
 * A view called ObjectList should be created containing objID, RA, DEC, Spatial (This is used by search functions)