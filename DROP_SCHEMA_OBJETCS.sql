/* *************************************************************************************************************

    This script is removing the objects in the current schema until every object has drop, or can not remove more.
    The remaining Objects (if there is still any) must drop by manually after reason of problem has eliminated.

    History of changes
    yyyy.mm.dd | Version | Author         | Changes
    -----------+---------+----------------+-------------------------
    2017.01.06 |  1.0    | Ferenc Toth    | Created 

************************************************************************************************************** */

declare

    V_PREV_COUNTER      integer := -1;
    V_COUNTER           integer :=  0;

begin

    -- wipe out all scheduler jobs
    for I in ( select * from user_scheduler_jobs )
    loop
        execute immediate 'exec dbms_scheduler.drop_job(job_name => '''||I.JOB_CREATOR||'.'||I.JOB_NAME||''')';
    end loop;

    -- wipe out all XML schemas
    for I in ( select * from user_xml_schemas )
    loop
        execute immediate 'exec dbms_xmlschema.deleteSchema(schemaURL => '''||I.QUAL_SCHEMA_URL||''',delete_option => dbms_xmlschema.DELETE_CASCADE_FORCE)';
    end loop;

    loop exit when V_PREV_COUNTER = V_COUNTER ;

        V_PREV_COUNTER := V_COUNTER;
        V_COUNTER      := 0;

        for I in ( select OBJECT_NAME
                        , OBJECT_TYPE
                     from USER_OBJECTS
                    where OBJECT_TYPE NOT IN ( 'INDEX PARTITION', 'TABLE PARTITION', 'LOB' )
                    order by OBJECT_TYPE desc
                 ) 
        loop

            V_COUNTER := V_COUNTER + 1;

            begin

                if I.OBJECT_TYPE = 'TYPE' then
 
                    execute immediate 'drop '||I.OBJECT_TYPE||' '||I.OBJECT_NAME||' force';
 
                elsif I.OBJECT_TYPE = 'QUEUE' then

                    DBMS_AQADM.STOP_QUEUE      ( QUEUE_NAME  => I.OBJECT_NAME );
                    DBMS_AQADM.DROP_QUEUE      ( QUEUE_NAME  => I.OBJECT_NAME );
                    DBMS_AQADM.DROP_QUEUE_TABLE( QUEUE_TABLE => I.OBJECT_NAME, force => true );  
 
                elsif I.OBJECT_TYPE = 'TABLE' then
 
                    execute immediate 'drop '||I.OBJECT_TYPE||' '||I.OBJECT_NAME||' cascade constraints purge';
 
                elsif I.OBJECT_TYPE = 'JOB' then

                    execute immediate 'exec dbms_scheduler.drop_job ('||I.OBJECT_NAME||')';

                else
 
                    execute immediate 'drop '||I.OBJECT_TYPE||' '||I.OBJECT_NAME;
 
                end if;

            exception when others then
                null;  -- we can not help it now.
            end;

        end loop;
            
    end loop;

end;
/


Prompt *************************************
Prompt   Remaining Objects
Prompt *************************************

SELECT OBJECT_NAME
     , OBJECT_TYPE
  FROM USER_OBJECTS
 ORDER BY OBJECT_TYPE
;

