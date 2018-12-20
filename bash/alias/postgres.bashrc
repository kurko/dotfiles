pg_db_size() {
  psql -d postgres -c "select pg_database_size('$1')"
}
