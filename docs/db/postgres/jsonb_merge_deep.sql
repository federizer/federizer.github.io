create or replace function public.jsonb_merge_deep(jsonb, jsonb)
  returns jsonb
  language sql
  immutable
as $func$
  select case jsonb_typeof($1)
    when 'object' then case jsonb_typeof($2)
      when 'object' then (
        select    jsonb_object_agg(k, case
                    when e2.v is null then e1.v
                    when e1.v is null then e2.v
                    else jsonb_merge_deep(e1.v, e2.v)
                  end)
        from      jsonb_each($1) e1(k, v)
        full join jsonb_each($2) e2(k, v) using (k)
      )
      else $2
    end
    when 'array' then $1 || $2
    else $2
  end
$func$;

ALTER FUNCTION public.jsonb_recursive_merge OWNER TO admin;
