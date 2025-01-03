-- Tabelas que mais seriam beneficiadas com novos índices.
SELECT TOP 15 db_name(db_id()) as base,
AVG((avg_total_user_cost * avg_user_impact * (user_seeks + user_scans))) as Impacto
	,mid.object_id
	, mid.statement as Tabela 
FROM sys.dm_db_missing_index_group_stats AS migs JOIN sys.dm_db_missing_index_groups AS mig 
	ON migs.group_handle = mig.index_group_handle JOIN sys.dm_db_missing_index_details AS mid 
	ON mig.index_handle = mid.index_handle 
		and database_id = db_id('databasename') 
GROUP BY mid.object_id
	, mid.statement 
ORDER BY Impacto DESC; 


-- Top 15 índices, sugeridos pelo SGBD.
/* DESCRICAO DOS CAMPOS:
Impacto: Quanto maior o impacto, mais benefícios serão obtidos com a criação do índice; 
Group_handle: Identificador único do índice sugerido. 
User_seeks: Quantidade de vezes, utilizando o método de busca “Index Seek”, que uma consulta realizada pelo usuário seria contemplada 
	por este índice, caso existisse; 
User_scan: Quantidade de vezes, utilizando o método de busca “Index Scan”, que uma consulta realizada pelo usuário seria contemplada 
	por este índice, caso existisse.; 
Object_id: Identificador único da tabela no banco de dados 
Statement: Tabela onde o índice deveria ser criado; 
Equality_columns: Colunas que fazem parte do Where de uma consulta utilizando o operador igual (=). 
	Ex: select * from tab where val = 1. Neste caso a coluna chamada “val”, aparecerá como resultado desta coluna. 
Inequality_columns: Colunas que fazem parte da clausula Where de uma consulta e se utilizam de operadores diferentres de igual (=)
	como os operadores (> < <> between); 
	Ex: select * from tab where val <> 1. 
Included_columns: Colunas que poderiam ser adicionadas para criar um Covered Index 
*/


SELECT TOP 15 
db_name(db_id()) as base,
(avg_total_user_cost * avg_user_impact * (user_seeks + user_scans)) as Impacto
	, migs.group_handle
	, mid.index_handle
	, migs.user_seeks
	,migs.user_scans
	, mid.object_id
	, mid.statement
	, mid.equality_columns
	, mid.inequality_columns
	, mid.included_columns 
FROM sys.dm_db_missing_index_group_stats AS migs JOIN sys.dm_db_missing_index_groups AS mig 
	ON migs.group_handle = mig.index_group_handle JOIN sys.dm_db_missing_index_details AS mid 
	ON mig.index_handle = mid.index_handle 
		and database_id = db_id('databasename') 
		-- and mid.object_id = object_id(‘tabela’) -- se desejar ver apenas para uma tabela específica 
ORDER BY Impacto DESC; 



-- Indices nunca utilizados
select db_name(db_id()) as base,
tb.name as Table_Name
	, ix.name as Index_Name
	, ix.type_desc
	, leaf_insert_count
	, leaf_delete_count
	, leaf_update_count
	, nonleaf_insert_count 
	, nonleaf_delete_count, nonleaf_update_count 
from sys.dm_db_index_usage_stats vw join sys.objects tb on tb.object_id = vw.object_id 
	join sys.indexes ix on ix.index_id = vw.index_id 
		and ix.object_id = tb.object_id 
	join sys.dm_db_index_operational_stats(db_id('databasename'), Null, NULL, NULL) vwx on vwx.object_id = tb.object_id 
		and vwx.index_id = ix.index_id 
where vw.database_id = db_id('databasename') 
	and vw.user_seeks = 0 
	and vw.user_scans = 0 
	and vw.user_lookups = 0 
	and vw.system_seeks = 0 
	and vw.system_scans = 0 
	and vw.system_lookups = 0 
Order By leaf_insert_count desc
	, tb.name asc
	, ix.name asc 




-- Avaliando Indices
select db_name(db_id()) as base,
ix.name
	, ix.type_desc
	, vwy.partition_number
	, vw.user_seeks
	, vw.last_user_seek
	, vw.user_scans
	, vw.last_user_scan
	, vw.user_lookups
	, vw.user_updates as 'Total_User_Escrita'
	, (vw.user_scans + vw.user_seeks + vw.user_lookups) as 'Total_User_Leitura'
	, vw.user_updates - (vw.user_scans + vw.user_seeks + vw.user_lookups) as '‘Dif_Read_Write’'
	, ix.allow_row_locks
	, vwx.row_lock_count
	, row_lock_wait_count
	, row_lock_wait_in_ms
	, ix.allow_page_locks
	, vwx.page_lock_count
	, page_lock_wait_count
	, page_lock_wait_in_ms
	, ix.fill_factor
	, ix.is_padded
	, vwy.avg_fragmentation_in_percent
	, vwy.avg_page_space_used_in_percent, ps.in_row_used_page_count as Total_Pagina_Usada
	, ps.in_row_reserved_page_count as Total_Pagina_Reservada
	, convert(real,ps.in_row_used_page_count) * 8192 / 1024 / 1024 as Total_Indice_Usado_MB
	,convert(real,ps.in_row_reserved_page_count) * 8192 / 1024 / 1024 as Total_Indice_Reservado_MB
	,page_io_latch_wait_count
	, page_io_latch_wait_in_ms 
from sys.dm_db_index_usage_stats vw join sys.indexes ix 
		on ix.index_id = vw.index_id 
			and ix.object_id = vw.object_id 
	join sys.dm_db_index_operational_stats(db_id('databasename'), OBJECT_ID('tabela'), NULL, NULL) vwx 
		on vwx.index_id = ix.index_id 
			and ix.object_id = vwx.object_id
	join sys.dm_db_index_physical_stats(db_id('databasename'), OBJECT_ID('tabela'), NULL, NULL , '') vwy 
		on vwy.index_id = ix.index_id 
			and ix.object_id = vwy.object_id 
			and vwy.partition_number = vwx.partition_number
	join sys.dm_db_partition_stats PS 
		on ps.index_id = vw.index_id 
			and ps.object_id = vw.object_id
where vw.database_id = db_id('databasename') AND object_name(vw.object_id) = 'tabela'
order by user_seeks desc
	, user_scans desc 


-- Tabelas com maiores qtde de indices
select 
db_name(db_id()) as base,
x.id
	, x.table_name
	, x.Total_index
	, count(*) as Total_column 
from sys.columns cl join 
	(select ix.object_id as id
		, tb.name as table_name
		, count(ix.object_id) as Total_index 
	 from sys.indexes ix join sys.objects tb on tb.object_id = ix.object_id and tb.type = 'U' 
	 group by ix.object_id, tb.name) x on x.id = cl.object_id 
group by id, table_name
	, Total_index 
order by 4 desc 

-- Consultas que mais utilizam CPU
SELECT TOP 10 db_name() as base, 
(total_worker_time/execution_count) / 1000 AS [Avg CPU Time ms]
	, SUBSTRING(st.text, (qs.statement_start_offset/2)+1
	, ((CASE qs.statement_end_offset WHEN -1 THEN DATALENGTH(st.text) ELSE qs.statement_end_offset
		END - qs.statement_start_offset)/2) + 1) AS statement_text
	, execution_count,last_execution_time
	, last_worker_time / 1000 as last_worker_time
	, min_worker_time / 1000 as min_worker_time
	, max_worker_time / 1000 as max_worker_time
	, total_physical_reads
	, last_physical_reads
	, min_physical_reads
	, max_physical_reads
	, total_logical_writes
	, last_logical_writes
	, min_logical_writes
	, max_logical_writes
	, query_plan
FROM sys.dm_exec_query_stats AS qs
	CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
	CROSS APPLY sys.dm_exec_text_query_plan(qs.plan_handle, DEFAULT, DEFAULT) AS qp
where (total_worker_time/execution_count) / 1000 > 0 
-- ORDER BY 2 DESC; 
