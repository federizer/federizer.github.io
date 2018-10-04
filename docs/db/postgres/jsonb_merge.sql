create or replace function jsonb_merge(a jsonb, b jsonb)
returns jsonb language sql as $$
select
    jsonb_object_agg(
        coalesce(ka, kb),
        case
            when va isnull then vb
            when vb isnull then va
            else va || vb
        end
    )
    from jsonb_each(a) e1(ka, va)
    full join jsonb_each(b) e2(kb, vb) on ka = kb
$$;

ALTER FUNCTION public.jsonb_merge OWNER TO admin;

