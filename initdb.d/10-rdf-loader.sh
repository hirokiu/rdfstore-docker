#!/bin/sh
set -eu

readonly data_dir=/data
readonly marker=/database/.rdf-load-complete
readonly sql_file=/database/autoexec.isql
readonly graph=${RDF_DEFAULT_GRAPH:?RDF_DEFAULT_GRAPH is required}

if printf '%s' "$graph" | grep -q "['[:cntrl:]]"; then
  echo "RDF_DEFAULT_GRAPH contains unsupported characters" >&2
  exit 1
fi

if ! find "$data_dir" -type f \
  \( -iname '*.ttl' -o -iname '*.nt' -o -iname '*.nq' -o -iname '*.rdf' \
     -o -iname '*.xml' -o -iname '*.owl' -o -iname '*.trig' \
     -o -iname '*.ttl.gz' -o -iname '*.nt.gz' -o -iname '*.nq.gz' \
     -o -iname '*.rdf.gz' -o -iname '*.xml.gz' -o -iname '*.owl.gz' \) \
  -print -quit | grep -q .; then
  echo "No supported RDF files found below $data_dir" >&2
  exit 1
fi

trap 'rm -f "$sql_file"' EXIT

cat >"$sql_file" <<SQL
log_enable (2, 1);
ld_dir_all ('$data_dir', '*.ttl', '$graph');
ld_dir_all ('$data_dir', '*.nt', '$graph');
ld_dir_all ('$data_dir', '*.nq', '$graph');
ld_dir_all ('$data_dir', '*.rdf', '$graph');
ld_dir_all ('$data_dir', '*.xml', '$graph');
ld_dir_all ('$data_dir', '*.owl', '$graph');
ld_dir_all ('$data_dir', '*.trig', '$graph');
ld_dir_all ('$data_dir', '*.ttl.gz', '$graph');
ld_dir_all ('$data_dir', '*.nt.gz', '$graph');
ld_dir_all ('$data_dir', '*.nq.gz', '$graph');
ld_dir_all ('$data_dir', '*.rdf.gz', '$graph');
ld_dir_all ('$data_dir', '*.xml.gz', '$graph');
ld_dir_all ('$data_dir', '*.owl.gz', '$graph');
rdf_loader_run ();
checkpoint;
select ll_file, ll_state, ll_error from DB.DBA.load_list where ll_state <> 2;
create procedure DB.DBA.RDFSTORE_ASSERT_INITIAL_LOAD ()
{
  declare failures integer;
  failures := (select count (*) from DB.DBA.load_list where ll_state <> 2);
  if (failures <> 0)
    signal ('RDFLD', sprintf ('%d RDF file(s) failed to load', failures));
};
DB.DBA.RDFSTORE_ASSERT_INITIAL_LOAD ();
drop procedure DB.DBA.RDFSTORE_ASSERT_INITIAL_LOAD;
SQL

echo "Registering and loading RDF files below $data_dir into $graph"
virtuoso-t -f +checkpoint-only

rm -f "$sql_file"
printf 'graph=%s\ncompleted_at=%s\n' "$graph" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$marker"
echo "RDF initial load completed"
