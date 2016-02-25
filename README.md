# SQLServerTAPSupport
Support functions in SQL for IVOA Table Access Protocol (TAP) services with a Microsoft SQL Server back end. 
Written at Space Telescope Science Institute as part of the NASA Astronomical Virtual Observatories (NAVO) project sponsored by NASA.

This repository contains SQL functions to install in a Microsoft SQL Server database for supporting specialized TAP services.
IVOA Table Access Protocol services are RESTful interfaces to tabular data with a variety of back end support databases. The TAP standard is defined here: http://www.ivoa.net/documents/TAP/
TAP services use the Astronomical Data Query Language (ADQL), which is a superset of SQL92, documented at http://www.ivoa.net/documents/latest/ADQL.html

Built on top of the generic TAP architecture are standards for other services with specified schemas for astronomical data and service metadata.
These specific schemas also require additional query functionality beyond the ADQL standard, and which are not built into Microsoft SQL Server. These functions are provided here.

For the Registry Table Access Protocol (RegTAP) standard, string search and concatenation functions are required.
http://www.ivoa.net/documents/RegTAP/ defines the RegTAP protocol, database schema, and these required functions.
Our implementation of these functions is in the directory "RegTAPFunctions". It is based on the GPLv3 package GroupConcat with source available at https://groupconcat.codeplex.com.

For the Observation Core Data Model Table Access Protocl (ObsTAP, using the ObsCore schema) standard, geometric and spatial query functions are required.
The ObsTAP standard is still officially a working draft according to the IVOA; reference implementations already exist.
The current version of the ObsTAP standard is available through: http://ivoa.net/documents/ObsCore/index.html
This project does not yet contain geometric functions for ObsTAP; as of Feb 25, 2016 they are in use in other ObsCore-based services and transferring these to our ADQL / TAP environment is an active project.