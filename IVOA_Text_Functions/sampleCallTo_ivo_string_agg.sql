-- sample call using a system table to return all the column names for a table(s) as one row of CSV

select object_name(c.object_id) as tableName, dbo.ivo_string_agg(c.name, ',') as columnNames
from sys.columns as c
inner join sys.tables as t on c.object_id=t.object_id
group by object_name(c.object_id)
order by object_name(c.object_id)

-- same as above but returning one row per column name
select object_name(c.object_id) as tableName, c.name
from sys.columns as c
inner join sys.tables as t on c.object_id=t.object_id
order by object_name(c.object_id), column_id
