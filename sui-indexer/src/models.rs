use crate::schema::{operators};
use diesel::prelude::*;

#[derive(Queryable, Selectable, Insertable, AsChangeset, Debug)]
#[diesel(table_name = operators)]
#[diesel(check_for_backend(diesel::pg::Pg))]
pub struct Operator {
    pub address: String
}