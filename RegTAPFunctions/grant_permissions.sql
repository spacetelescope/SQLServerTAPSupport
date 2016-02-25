DECLARE @readonlyusername varchar(30) = 'nvowebaccess';

--select 'grant execute on ' + name + ' to @readonlyuser', name, create_date from sys.objects where name like 'ivo%' order by create_date desc

SET @readonlyusername = quotename(@readonlyusername)

exec('grant execute on ivo_nocasematch to ' + @readonlyusername)
exec('grant execute on ivo_hasword to ' + @readonlyusername)
exec('grant execute on ivo_string_agg to ' + @readonlyusername)
exec('grant execute on ivo_hashlist_has to' + @readonlyusername)


